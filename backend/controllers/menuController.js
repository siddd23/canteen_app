const Canteen = require("../models/Canteen");
const MenuCategory = require("../models/MenuCategory");
const MenuItem = require("../models/MenuItem");

const findOwnedCanteen = (canteenId, ownerId) =>
  Canteen.findOne({
    _id: canteenId,
    ownerId,
  });

const trimValue = (value) =>
  typeof value === "string" ? value.trim() : value;

const buildMenuSummary = (categories, items) => ({
  totalCategories: categories.length,
  activeCategories: categories.filter(
    (category) => category.status === "Active",
  ).length,
  totalItems: items.length,
  availableItems: items.filter((item) => item.isAvailable).length,
  unavailableItems: items.filter((item) => !item.isAvailable).length,
});

/*
 * GET /api/canteens/:canteenId/menu
 */
const getMyCanteenMenu = async (req, res, next) => {
  try {
    const canteen = await findOwnedCanteen(
      req.params.canteenId,
      req.user.id,
    );

    if (!canteen) {
      return res.status(404).json({
        success: false,
        message: "Canteen not found",
      });
    }

    const [categories, items] = await Promise.all([
      MenuCategory.find({
        canteenId: canteen._id,
        ownerId: req.user.id,
      }).sort({ displayOrder: 1, createdAt: 1 }),

      MenuItem.find({
        canteenId: canteen._id,
        ownerId: req.user.id,
      }).sort({ categoryId: 1, name: 1 }),
    ]);

    return res.status(200).json({
      success: true,
      data: {
        canteen,
        categories,
        items,
        summary: buildMenuSummary(categories, items),
      },
    });
  } catch (error) {
    next(error);
  }
};

/*
 * POST /api/canteens/:canteenId/menu/categories
 */
const createMenuCategory = async (req, res, next) => {
  try {
    const canteen = await findOwnedCanteen(
      req.params.canteenId,
      req.user.id,
    );

    if (!canteen) {
      return res.status(404).json({
        success: false,
        message: "Canteen not found",
      });
    }

    const category = await MenuCategory.create({
      ownerId: req.user.id,
      canteenId: canteen._id,
      name: trimValue(req.body.name),
      displayOrder: req.body.displayOrder ?? 0,
      status: req.body.status ?? "Active",
    });

    return res.status(201).json({
      success: true,
      message: "Menu category created successfully",
      data: {
        category,
      },
    });
  } catch (error) {
    next(error);
  }
};

/*
 * PATCH /api/canteens/:canteenId/menu/categories/:categoryId
 */
const updateMenuCategory = async (req, res, next) => {
  try {
    const canteen = await findOwnedCanteen(
      req.params.canteenId,
      req.user.id,
    );

    if (!canteen) {
      return res.status(404).json({
        success: false,
        message: "Canteen not found",
      });
    }

    const allowedFields = ["name", "displayOrder", "status"];
    const updates = {};

    allowedFields.forEach((field) => {
      if (req.body[field] !== undefined) {
        updates[field] = trimValue(req.body[field]);
      }
    });

    const category = await MenuCategory.findOneAndUpdate(
      {
        _id: req.params.categoryId,
        canteenId: canteen._id,
        ownerId: req.user.id,
      },
      updates,
      {
        new: true,
        runValidators: true,
      },
    );

    if (!category) {
      return res.status(404).json({
        success: false,
        message: "Menu category not found",
      });
    }

    return res.status(200).json({
      success: true,
      message: "Menu category updated successfully",
      data: {
        category,
      },
    });
  } catch (error) {
    next(error);
  }
};

/*
 * POST /api/canteens/:canteenId/menu/items
 */
const createMenuItem = async (req, res, next) => {
  try {
    const canteen = await findOwnedCanteen(
      req.params.canteenId,
      req.user.id,
    );

    if (!canteen) {
      return res.status(404).json({
        success: false,
        message: "Canteen not found",
      });
    }

    const category = await MenuCategory.findOne({
      _id: req.body.categoryId,
      canteenId: canteen._id,
      ownerId: req.user.id,
    });

    if (!category) {
      return res.status(400).json({
        success: false,
        message: "The selected category does not belong to this canteen",
      });
    }

    const item = await MenuItem.create({
      ownerId: req.user.id,
      canteenId: canteen._id,
      categoryId: category._id,
      name: trimValue(req.body.name),
      description: trimValue(req.body.description) || "",
      price: Math.round(Number(req.body.price) * 100) / 100,
      foodType: req.body.foodType ?? "Vegetarian",
      preparationTime: req.body.preparationTime ?? 0,
      imageUrl: trimValue(req.body.imageUrl) || "",
      isAvailable: req.body.isAvailable ?? true,
    });

    return res.status(201).json({
      success: true,
      message: "Menu item created successfully",
      data: {
        item,
      },
    });
  } catch (error) {
    next(error);
  }
};

/*
 * PATCH /api/canteens/:canteenId/menu/items/:itemId
 */
const updateMenuItem = async (req, res, next) => {
  try {
    const canteen = await findOwnedCanteen(
      req.params.canteenId,
      req.user.id,
    );

    if (!canteen) {
      return res.status(404).json({
        success: false,
        message: "Canteen not found",
      });
    }

    if (req.body.categoryId !== undefined) {
      const category = await MenuCategory.findOne({
        _id: req.body.categoryId,
        canteenId: canteen._id,
        ownerId: req.user.id,
      });

      if (!category) {
        return res.status(400).json({
          success: false,
          message: "The selected category does not belong to this canteen",
        });
      }
    }

    const allowedFields = [
      "categoryId",
      "name",
      "description",
      "price",
      "foodType",
      "preparationTime",
      "imageUrl",
      "isAvailable",
    ];
    const updates = {};

    allowedFields.forEach((field) => {
      if (req.body[field] !== undefined) {
        updates[field] = trimValue(req.body[field]);
      }
    });

    if (updates.price !== undefined) {
      updates.price = Math.round(Number(updates.price) * 100) / 100;
    }

    const item = await MenuItem.findOneAndUpdate(
      {
        _id: req.params.itemId,
        canteenId: canteen._id,
        ownerId: req.user.id,
      },
      updates,
      {
        new: true,
        runValidators: true,
      },
    );

    if (!item) {
      return res.status(404).json({
        success: false,
        message: "Menu item not found",
      });
    }

    return res.status(200).json({
      success: true,
      message: "Menu item updated successfully",
      data: {
        item,
      },
    });
  } catch (error) {
    next(error);
  }
};

/*
 * PATCH /api/canteens/:canteenId/menu/items/:itemId/availability
 */
const updateMenuItemAvailability = async (req, res, next) => {
  try {
    const canteen = await findOwnedCanteen(
      req.params.canteenId,
      req.user.id,
    );

    if (!canteen) {
      return res.status(404).json({
        success: false,
        message: "Canteen not found",
      });
    }

    const item = await MenuItem.findOneAndUpdate(
      {
        _id: req.params.itemId,
        canteenId: canteen._id,
        ownerId: req.user.id,
      },
      {
        isAvailable: req.body.isAvailable,
      },
      {
        new: true,
        runValidators: true,
      },
    );

    if (!item) {
      return res.status(404).json({
        success: false,
        message: "Menu item not found",
      });
    }

    return res.status(200).json({
      success: true,
      message: item.isAvailable
        ? "Menu item is now available"
        : "Menu item marked unavailable",
      data: {
        item,
      },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getMyCanteenMenu,
  createMenuCategory,
  updateMenuCategory,
  createMenuItem,
  updateMenuItem,
  updateMenuItemAvailability,
};
