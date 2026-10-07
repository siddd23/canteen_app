const crypto = require("crypto");
const QRCode = require("qrcode");

const Canteen = require("../models/Canteen");

const orderingWebUrl = () =>
  (process.env.ORDERING_WEB_URL || process.env.APP_BASE_URL || "http://localhost:3000")
    .replace(/\/+$/, "");

const createUniquePublicCode = async () => {
  for (let attempt = 0; attempt < 10; attempt += 1) {
    const code = `CNT-${crypto.randomBytes(4).toString("hex").toUpperCase()}`;
    if (!(await Canteen.exists({ publicCode: code }))) return code;
  }
  throw new Error("Unable to generate a unique canteen public code");
};

const buildMasterQr = async (publicCode) => {
  const masterOrderingUrl =
    `${orderingWebUrl()}/canteen/${encodeURIComponent(publicCode)}`;
  const masterQrCode = await QRCode.toDataURL(masterOrderingUrl, {
    errorCorrectionLevel: "H",
    margin: 2,
    width: 720,
    color: { dark: "#111111", light: "#FFFFFF" },
  });
  return { masterOrderingUrl, masterQrCode };
};

const createMasterQrFields = async () => {
  const publicCode = await createUniquePublicCode();
  return {
    publicCode,
    ...(await buildMasterQr(publicCode)),
    masterQrEnabled: true,
  };
};

const ensureCanteenMasterQr = async (canteen) => {
  if (canteen.publicCode && canteen.masterOrderingUrl && canteen.masterQrCode) {
    return canteen;
  }
  const fields = await createMasterQrFields();
  canteen.publicCode = fields.publicCode;
  canteen.masterOrderingUrl = fields.masterOrderingUrl;
  canteen.masterQrCode = fields.masterQrCode;
  if (canteen.masterQrEnabled === undefined) canteen.masterQrEnabled = true;
  await canteen.save();
  return canteen;
};

module.exports = { createMasterQrFields, ensureCanteenMasterQr };
