const Customer = require('../models/Customer');
const Order = require('../models/Order');

const keys = ['buildingName','floorOrRoom','streetArea','city','pincode'];
const clean = (value) => Object.fromEntries(keys.map((k) => [k, String(value?.[k] || '').trim()]));
const valid = (a) => a.buildingName.length >= 2 && a.floorOrRoom.length >= 1 && a.streetArea.length >= 3 && a.city.length >= 2 && /^\d{6}$/.test(a.pincode);
const same = (a,b) => keys.every((k) => String(a?.[k] || '').trim().toLowerCase() === String(b?.[k] || '').trim().toLowerCase());

// Migration runs once per customer only when there are no saved addresses.
// Older orders belong to an authenticated customer via customerId; never by mobile number.
async function recover(customer) {
  if (customer.savedAddresses?.length) return customer;
  let a = clean(customer.deliveryAddress);
  if (!valid(a)) {
    const order = await Order.findOne({ customerId: customer._id, 'deliveryAddress.buildingName': { $ne: '' } })
      .select('deliveryAddress').sort({ createdAt: -1 }).lean();
    a = clean(order?.deliveryAddress);
  }
  if (!valid(a)) return customer;
  // Conditional update avoids duplicate migrations from simultaneous app requests.
  await Customer.updateOne({ _id: customer._id, 'savedAddresses.0': { $exists: false } },
    { $push: { savedAddresses: { ...a, label: 'Work', isDefault: true } }, $set: { deliveryAddress: a } });
  return Customer.findById(customer._id);
}
const present = (c) => c.savedAddresses.map((a) => ({ id: String(a._id), label: a.label, isDefault: a.isDefault, ...clean(a) }));

const list = async (req, res, next) => {
  try { const c = await recover(await Customer.findById(req.customer._id)); return res.json({ success: true, data: { addresses: present(c) } }); }
  catch(e) { next(e); }
};
const add = async (req, res, next) => {
  try {
    const c = await recover(await Customer.findById(req.customer._id));
    const a = clean(req.body);
    if (!valid(a)) return res.status(400).json({ success: false, message: 'Enter a complete delivery address' });
    const label = String(req.body.label || 'Work').trim().slice(0,30) || 'Work';
    const found = c.savedAddresses.find((entry) => same(entry, a));
    if (found) {
      if (req.body.isDefault === true) c.savedAddresses.forEach((entry) => { entry.isDefault = entry._id.equals(found._id); });
    } else {
      if (c.savedAddresses.length >= 10) return res.status(400).json({ success: false, message: 'Maximum 10 addresses allowed' });
      const isDefault = req.body.isDefault === true || c.savedAddresses.length === 0;
      if (isDefault) c.savedAddresses.forEach((entry) => { entry.isDefault = false; });
      c.savedAddresses.push({ ...a, label, isDefault });
    }
    const selected = found || c.savedAddresses[c.savedAddresses.length - 1];
    if (selected.isDefault) c.deliveryAddress = a;
    await c.save();
    return res.status(201).json({ success: true, data: { addresses: present(c), selectedId: String(selected._id) } });
  } catch(e) { next(e); }
};
const update = async (req, res, next) => {
  try {
    const c = await Customer.findById(req.customer._id);
    const a = c.savedAddresses.id(req.params.id);
    if (!a) return res.status(404).json({ success: false, message: 'Address not found' });
    const cleanAddress = clean(req.body);
    if (!valid(cleanAddress)) return res.status(400).json({ success: false, message: 'Enter a complete delivery address' });
    Object.assign(a, cleanAddress, { label: String(req.body.label || a.label || 'Work').trim().slice(0,30) });
    if (req.body.isDefault === true) c.savedAddresses.forEach((entry) => { entry.isDefault = entry._id.equals(a._id); });
    if (a.isDefault) c.deliveryAddress = cleanAddress;
    await c.save();
    return res.json({ success: true, data: { addresses: present(c), selectedId: String(a._id) } });
  } catch(e) { next(e); }
};
const remove = async (req, res, next) => {
  try {
    const c = await Customer.findById(req.customer._id);
    const a = c.savedAddresses.id(req.params.id);
    if (!a) return res.status(404).json({ success: false, message: 'Address not found' });
    const wasDefault = a.isDefault;
    c.savedAddresses.pull(a._id);
    if (wasDefault && c.savedAddresses.length) c.savedAddresses[0].isDefault = true;
    c.deliveryAddress = c.savedAddresses.find((entry) => entry.isDefault)
      ? clean(c.savedAddresses.find((entry) => entry.isDefault)) : clean(null);
    await c.save();
    return res.json({ success: true, data: { addresses: present(c) } });
  } catch(e) { next(e); }
};
const setDefault = async (req, res, next) => {
  try {
    const c = await Customer.findById(req.customer._id);
    const target = c.savedAddresses.id(req.params.id);
    if (!target) return res.status(404).json({ success: false, message: 'Address not found' });
    c.savedAddresses.forEach((entry) => { entry.isDefault = entry._id.equals(target._id); });
    c.deliveryAddress = clean(target);
    await c.save();
    return res.json({ success: true, data: { addresses: present(c) } });
  } catch(e) { next(e); }
};
module.exports = { list, add, update, remove, setDefault };
