const Canteen = require("../models/Canteen");
const {
  createMasterQrFields,
  ensureCanteenMasterQr,
} = require("../services/canteenMasterQrService");

const normalizeServiceSlots = (slots, openingTime, closingTime) => {
  if (!Array.isArray(slots) || slots.length !== 2) return [];
  return slots.map((slot, index) => ({
    label: String(slot.label || (index === 0 ? "Lunch" : "Dinner")).trim(),
    openingTime: String(slot.openingTime || openingTime || "").trim(),
    closingTime: String(slot.closingTime || closingTime || "").trim(),
  }));
};

/*
 * POST /api/canteens
 * Approved canteen owner
 */
const createCanteen = async (req, res, next) => {
  try {
    const {
      name,
      address,
      city,
      contactNumber,
      openingTime,
      closingTime,
      serviceSlots,
    } = req.body;

    const normalizedSlots = normalizeServiceSlots(serviceSlots, openingTime, closingTime);

    const existingCanteen = await Canteen.findOne({
      ownerId: req.user.id,
      name: name.trim(),
    }).collation({
      locale: "en",
      strength: 2,
    });

    if (existingCanteen) {
      return res.status(409).json({
        success: false,
        message: "You already have a canteen with this name",
      });
    }

    const masterQr = await createMasterQrFields();
    const canteen = await Canteen.create({
      ownerId: req.user.id,
      name: name.trim(),
      address: address.trim(),
      city: city.trim(),
      contactNumber: contactNumber.trim(),
      openingTime: openingTime.trim(),
      closingTime: closingTime.trim(),
      serviceSlots: normalizedSlots,
      ...masterQr,
    });

    return res.status(201).json({
      success: true,
      message: "Canteen created successfully",
      data: {
        canteen,
      },
    });
  } catch (error) {
    next(error);
  }
};

/*
 * GET /api/canteens
 * Return only the logged-in owner's canteens
 */
const getMyCanteens = async (req, res, next) => {
  try {
    const canteens = await Canteen.find({
      ownerId: req.user.id,
    }).sort({
      createdAt: 1,
    });

    await Promise.all(canteens.map(ensureCanteenMasterQr));

    return res.status(200).json({
      success: true,
      count: canteens.length,
      data: {
        canteens,
        hasCanteens: canteens.length > 0,
      },
    });
  } catch (error) {
    next(error);
  }
};

/*
 * GET /api/canteens/:canteenId
 */
const getMyCanteenById = async (req, res, next) => {
  try {
    const canteen = await Canteen.findOne({
      _id: req.params.canteenId,
      ownerId: req.user.id,
    });

    if (!canteen) {
      return res.status(404).json({
        success: false,
        message: "Canteen not found",
      });
    }

    await ensureCanteenMasterQr(canteen);

    return res.status(200).json({
      success: true,
      data: {
        canteen,
      },
    });
  } catch (error) {
    next(error);
  }
};

/*
 * PATCH /api/canteens/:canteenId
 */
const updateMyCanteen = async (req, res, next) => {
  try {
    const allowedFields = [
      "name",
      "address",
      "city",
      "contactNumber",
      "openingTime",
      "closingTime",
      "serviceSlots",
      "status",
    ];

    const updates = {};

    allowedFields.forEach((field) => {
      if (req.body[field] !== undefined) {
        updates[field] =
          typeof req.body[field] === "string"
            ? req.body[field].trim()
            : req.body[field];
      }
    });

    if (updates.serviceSlots) {
      updates.serviceSlots = normalizeServiceSlots(
        updates.serviceSlots,
        updates.openingTime,
        updates.closingTime,
      );
      updates.openingTime = updates.serviceSlots[0].openingTime;
      updates.closingTime = updates.serviceSlots[1].closingTime;
    }

    if (updates.name) {
      const duplicateCanteen = await Canteen.findOne({
        ownerId: req.user.id,
        name: updates.name,
        _id: {
          $ne: req.params.canteenId,
        },
      }).collation({
        locale: "en",
        strength: 2,
      });

      if (duplicateCanteen) {
        return res.status(409).json({
          success: false,
          message: "You already have another canteen with this name",
        });
      }
    }

    const canteen = await Canteen.findOneAndUpdate(
      {
        _id: req.params.canteenId,
        ownerId: req.user.id,
      },
      updates,
      {
        new: true,
        runValidators: true,
      }
    );

    if (!canteen) {
      return res.status(404).json({
        success: false,
        message: "Canteen not found",
      });
    }

    return res.status(200).json({
      success: true,
      message: "Canteen updated successfully",
      data: {
        canteen,
      },
    });
  } catch (error) {
    next(error);
  }
};

/*
 * PATCH /api/canteens/:canteenId/status
 *
 * We use Active/Inactive instead of permanently deleting a canteen,
 * because orders and payment records will reference it later.
 */
const updateCanteenStatus = async (req, res, next) => {
  try {
    const canteen = await Canteen.findOneAndUpdate(
      {
        _id: req.params.canteenId,
        ownerId: req.user.id,
      },
      {
        status: req.body.status,
      },
      {
        new: true,
        runValidators: true,
      }
    );

    if (!canteen) {
      return res.status(404).json({
        success: false,
        message: "Canteen not found",
      });
    }

    return res.status(200).json({
      success: true,
      message: `Canteen marked as ${canteen.status.toLowerCase()}`,
      data: {
        canteen,
      },
    });
  } catch (error) {
    next(error);
  }
};

const updateMasterQrStatus = async (req, res, next) => {
  try {
    const canteen = await Canteen.findOne({
      _id: req.params.canteenId,
      ownerId: req.user.id,
    });

    if (!canteen) {
      return res.status(404).json({ success: false, message: "Canteen not found" });
    }

    await ensureCanteenMasterQr(canteen);
    const permanentCode = canteen.publicCode;
    const permanentUrl = canteen.masterOrderingUrl;
    canteen.masterQrEnabled = req.body.enabled;
    await canteen.save();

    if (
      canteen.publicCode !== permanentCode ||
      canteen.masterOrderingUrl !== permanentUrl
    ) {
      throw new Error("Master QR identity changed while updating its status");
    }

    return res.status(200).json({
      success: true,
      message: `Master QR ordering ${canteen.masterQrEnabled ? "enabled" : "paused"}`,
      data: {
        canteen,
        permanentIdentity: {
          publicCode: permanentCode,
          masterOrderingUrl: permanentUrl,
        },
      },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createCanteen,
  getMyCanteens,
  getMyCanteenById,
  updateMyCanteen,
  updateCanteenStatus,
  updateMasterQrStatus,
};
