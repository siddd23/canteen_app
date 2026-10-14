const crypto = require("crypto");
const QRCode = require("qrcode");

const Canteen = require("../models/Canteen");
const Office = require("../models/Office");

const officePopulation = {
  path: "canteenIds",
  select:
    "name address city contactNumber openingTime closingTime serviceSlots status",
};

const trimText = (value) =>
  typeof value === "string" ? value.trim() : value;

const createUniqueOfficeCode = async () => {
  for (let attempt = 0; attempt < 10; attempt += 1) {
    const randomPart = crypto.randomBytes(4).toString("hex").toUpperCase();
    const officeCode = `OFC-${randomPart}`;

    const exists = await Office.exists({ officeCode });

    if (!exists) {
      return officeCode;
    }
  }

  throw new Error("Unable to generate a unique office code");
};

const getOwnedCanteens = async ({ canteenIds, ownerId }) => {
  const uniqueCanteenIds = [...new Set(canteenIds.map(String))];

  const canteens = await Canteen.find({
    _id: {
      $in: uniqueCanteenIds,
    },
    ownerId,
  });

  return {
    canteens,
    uniqueCanteenIds,
  };
};

/*
 * POST /api/offices
 * Register an office and generate its permanent QR code.
 */
const createOffice = async (req, res, next) => {
  try {
    const {
      companyName,
      building,
      floor,
      address,
      city,
      state,
      pincode,
      contactPerson,
      contactNumber,
      canteenIds,
    } = req.body;

    const { canteens, uniqueCanteenIds } = await getOwnedCanteens({
      canteenIds,
      ownerId: req.user.id,
    });

    if (canteens.length !== uniqueCanteenIds.length) {
      return res.status(400).json({
        success: false,
        message:
          "One or more selected canteens do not belong to your account",
      });
    }

    const officeCode = await createUniqueOfficeCode();

    const applicationUrl = (
      process.env.ORDERING_WEB_URL ||
      process.env.APP_BASE_URL ||
      "http://localhost:3000"
    ).replace(/\/+$/, "");

    const orderingUrl =
      `${applicationUrl}/order/${encodeURIComponent(officeCode)}`;

    const qrCode = await QRCode.toDataURL(orderingUrl, {
      errorCorrectionLevel: "H",
      margin: 2,
      width: 720,
      color: {
        dark: "#172033",
        light: "#FFFFFF",
      },
    });

    const office = await Office.create({
      ownerId: req.user.id,
      canteenIds: uniqueCanteenIds,
      companyName: trimText(companyName),
      building: trimText(building),
      floor: trimText(floor) || "",
      address: trimText(address),
      city: trimText(city),
      state: trimText(state),
      pincode: trimText(pincode),
      contactPerson: trimText(contactPerson),
      contactNumber: trimText(contactNumber),
      officeCode,
      orderingUrl,
      qrCode,
    });

    await office.populate(officePopulation);

    return res.status(201).json({
      success: true,
      message: "Office registered and QR code generated successfully",
      data: {
        office,
      },
    });
  } catch (error) {
    next(error);
  }
};

/*
 * GET /api/offices
 * List offices belonging to the authenticated owner.
 */
const getMyOffices = async (req, res, next) => {
  try {
    const offices = await Office.find({
      ownerId: req.user.id,
    })
      .populate(officePopulation)
      .sort({
        createdAt: -1,
      });

    return res.status(200).json({
      success: true,
      count: offices.length,
      data: {
        offices,
      },
    });
  } catch (error) {
    next(error);
  }
};

/*
 * GET /api/offices/:officeId
 */
const getMyOfficeById = async (req, res, next) => {
  try {
    const office = await Office.findOne({
      _id: req.params.officeId,
      ownerId: req.user.id,
    }).populate(officePopulation);

    if (!office) {
      return res.status(404).json({
        success: false,
        message: "Office not found",
      });
    }

    return res.status(200).json({
      success: true,
      data: {
        office,
      },
    });
  } catch (error) {
    next(error);
  }
};

/*
 * PATCH /api/offices/:officeId/canteens
 * Change canteens available through the existing QR.
 */
const updateOfficeCanteens = async (req, res, next) => {
  try {
    const { canteenIds } = req.body;

    const { canteens, uniqueCanteenIds } = await getOwnedCanteens({
      canteenIds,
      ownerId: req.user.id,
    });

    if (canteens.length !== uniqueCanteenIds.length) {
      return res.status(400).json({
        success: false,
        message:
          "One or more selected canteens do not belong to your account",
      });
    }

    const office = await Office.findOneAndUpdate(
      {
        _id: req.params.officeId,
        ownerId: req.user.id,
      },
      {
        canteenIds: uniqueCanteenIds,
      },
      {
        new: true,
        runValidators: true,
      },
    ).populate(officePopulation);

    if (!office) {
      return res.status(404).json({
        success: false,
        message: "Office not found",
      });
    }

    return res.status(200).json({
      success: true,
      message: "Office canteens updated successfully",
      data: {
        office,
      },
    });
  } catch (error) {
    next(error);
  }
};

/*
 * PATCH /api/offices/:officeId/status
 */
const updateOfficeStatus = async (req, res, next) => {
  try {
    const office = await Office.findOneAndUpdate(
      {
        _id: req.params.officeId,
        ownerId: req.user.id,
      },
      {
        status: req.body.status,
      },
      {
        new: true,
        runValidators: true,
      },
    ).populate(officePopulation);

    if (!office) {
      return res.status(404).json({
        success: false,
        message: "Office not found",
      });
    }

    return res.status(200).json({
      success: true,
      message: `Office marked as ${office.status.toLowerCase()}`,
      data: {
        office,
      },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createOffice,
  getMyOffices,
  getMyOfficeById,
  updateOfficeCanteens,
  updateOfficeStatus,
};
