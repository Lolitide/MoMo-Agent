
const fs = require('fs'), zlib = require('zlib');
const src = process.argv[2], dst = process.argv[3], keepH = parseInt(process.argv[4], 10);
const SIG = Buffer.from([0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A]);
function crc32(b) { let c, table = []; for (let n = 0; n < 256; n++) { c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1; table[n] = c >>> 0; } let crc = 0xFFFFFFFF; for (let i = 0; i < b.length; i++) crc = table[(crc ^ b[i]) & 0xFF] ^ (crc >>> 8); return (crc ^ 0xFFFFFFFF) >>> 0; }
function chunk(type, data) { const t = Buffer.from(type, 'ascii'); const body = Buffer.concat([t, data]); const c = Buffer.alloc(12 + data.length); c.writeUInt32BE(data.length, 0); t.copy(c, 4); data.copy(c, 8); c.writeUInt32BE(crc32(body), 8 + data.length); return c; }
const buf = fs.readFileSync(src);
let pos = 8, width = 0, height = 0, idat = [];
while (pos < buf.length) {
  const len = buf.readUInt32BE(pos), type = buf.toString('ascii', pos + 4, pos + 8);
  if (type === 'IHDR') { width = buf.readUInt32BE(pos + 8); height = buf.readUInt32BE(pos + 12); }
  if (type === 'IDAT') idat.push(buf.subarray(pos + 8, pos + 8 + len));
  pos += 12 + len; if (type === 'IEND') break;
}
console.log('in: ' + width + 'x' + height + ' -> keep ' + keepH);
const raw = zlib.inflateSync(Buffer.concat(idat));
const ihdr = readIHDR(buf);
const ch = ihdr.ct === 0 ? 1 : ihdr.ct === 2 ? 3 : ihdr.ct === 4 ? 2 : 4;
const stride = width * ch;
const rows = []; let off = 0;
for (let y = 0; y < height; y++) {
  const f = raw[off++]; const row = Buffer.from(raw.subarray(off, off + stride)); off += stride;
  if (f === 1) { for (let i = ch; i < stride; i++) row[i] = (row[i] + row[i - ch]) & 0xFF; }
  else if (f === 2) { const prev = rows.length ? rows[rows.length - 1] : Buffer.alloc(stride); for (let i = 0; i < stride; i++) row[i] = (row[i] + prev[i]) & 0xFF; }
  else if (f === 3) { const prev = rows.length ? rows[rows.length - 1] : Buffer.alloc(stride); for (let i = 0; i < stride; i++) { const a = i >= ch ? row[i - ch] : 0; row[i] = (row[i] + ((a + prev[i]) >> 1)) & 0xFF; } }
  else if (f === 4) { const prev = rows.length ? rows[rows.length - 1] : Buffer.alloc(stride); for (let i = 0; i < stride; i++) { const a = i >= ch ? row[i - ch] : 0, b = prev[i], c = i >= ch ? prev[i - ch] : 0; const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c); row[i] = (row[i] + (pa <= pb && pa <= pc ? a : pb <= pc ? b : c)) & 0xFF; } }
  rows.push(row);
}
const outRows = rows.slice(height - keepH, height);
const enc = Buffer.alloc(keepH * (stride + 1));
for (let y = 0; y < keepH; y++) { enc[y * (stride + 1)] = 0; outRows[y].copy(enc, y * (stride + 1) + 1); }
const ihdrB = Buffer.alloc(13); ihdrB.writeUInt32BE(width, 0); ihdrB.writeUInt32BE(keepH, 4); ihdrB[8] = ihdr.bd; ihdrB[9] = ihdr.ct; ihdrB[10] = 0; ihdrB[11] = 0; ihdrB[12] = 0;
const parts = [SIG, chunk('IHDR', ihdrB), chunk('IDAT', zlib.deflateSync(enc, { level: 9 })), chunk('IEND', Buffer.alloc(0))];
fs.writeFileSync(dst, Buffer.concat(parts));
console.log('done');
function readIHDR(b) { const p = 8 + 8; return { w: b.readUInt32BE(p), h: b.readUInt32BE(p + 4), bd: b[p + 8], ct: b[p + 9] }; }
