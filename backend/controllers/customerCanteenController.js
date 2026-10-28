const Customer = require('../models/Customer');
const Canteen = require('../models/Canteen');

const fields = 'name address city publicCode openingTime closingTime status masterQrEnabled';
const listed = (canteen) => ({
  id: String(canteen._id), name: canteen.name, address: canteen.address,
  city: canteen.city, publicCode: canteen.publicCode,
  openingTime: canteen.openingTime, closingTime: canteen.closingTime,
  available: canteen.status === 'Active' && canteen.masterQrEnabled === true,
});

const list = async (req, res, next) => {
  try {
    const customer = await Customer.findById(req.customer._id).select('savedCanteens').lean();
    const canteens = await Canteen.find({ _id: { $in: customer.savedCanteens || [] } }).select(fields).lean();
    const byId = new Map(canteens.map((c) => [String(c._id), c]));
    res.json({ success: true, data: { canteens: (customer.savedCanteens || []).map((id) => byId.get(String(id))).filter(Boolean).map(listed) } });
  } catch (error) { next(error); }
};
const add = async (req, res, next) => {
  try {
    const code = req.body.code.trim().toUpperCase();
    const canteen = await Canteen.findOne({ publicCode: code, status: 'Active', masterQrEnabled: true }).select(fields).lean();
    if (!canteen) return res.status(404).json({ success: false, message: 'Canteen code not found or ordering is currently unavailable.' });
    const result = await Customer.updateOne({ _id: req.customer._id, savedCanteens: { $ne: canteen._id } }, { $addToSet: { savedCanteens: canteen._id } });
    if (!result.modifiedCount) return res.status(409).json({ success: false, message: 'This canteen is already in your collection.' });
    res.status(201).json({ success: true, message: 'Canteen added successfully', data: { canteen: listed(canteen) } });
  } catch (error) { next(error); }
};
const remove = async (req, res, next) => {
  try {
    await Customer.updateOne({ _id: req.customer._id }, { $pull: { savedCanteens: req.params.id } });
    res.json({ success: true, message: 'Canteen removed' });
  } catch (error) { next(error); }
};
module.exports = { list, add, remove };
