import ExcelJS from 'exceljs';
import PDFDocument from 'pdfkit';

export async function buildSalesExcel(payload: {
  branch_id: string | null;
  range: { from: string; to: string };
  totals: { orders: number; subtotal: number; discount: number; tax: number; total: number };
  orders: Array<{ orderNumber: string; branchId: string; total: number; paidAt: Date | string }>;
}) {
  const wb = new ExcelJS.Workbook();
  const ws = wb.addWorksheet('Sales');

  ws.addRow(['Sales Report']);
  ws.addRow([`Range: ${payload.range.from} - ${payload.range.to}`]);
  ws.addRow([`Branch: ${payload.branch_id ?? 'ALL'}`]);
  ws.addRow([]);

  ws.addRow(['Orders', payload.totals.orders]);
  ws.addRow(['Subtotal', payload.totals.subtotal]);
  ws.addRow(['Discount', payload.totals.discount]);
  ws.addRow(['Tax', payload.totals.tax]);
  ws.addRow(['Total', payload.totals.total]);
  ws.addRow([]);

  ws.addRow(['Paid At', 'Order Number', 'Branch ID', 'Total']);
  ws.getRow(ws.rowCount).font = { bold: true };

  for (const o of payload.orders) {
    ws.addRow([
      typeof o.paidAt === 'string' ? o.paidAt : o.paidAt?.toISOString?.() ?? '',
      o.orderNumber,
      o.branchId,
      o.total,
    ]);
  }

  ws.columns.forEach((c) => {
    c.width = Math.max(12, (c.header?.toString().length ?? 12) + 2);
  });

  return wb.xlsx.writeBuffer();
}

export function buildSalesPdf(payload: {
  branch_id: string | null;
  range: { from: string; to: string };
  totals: { orders: number; subtotal: number; discount: number; tax: number; total: number };
  orders: Array<{ orderNumber: string; branchId: string; total: number; paidAt: Date | string }>;
}) {
  const doc = new PDFDocument({ size: 'A4', margin: 40 });

  doc.fontSize(18).text('Sales Report', { align: 'center' });
  doc.moveDown(0.5);
  doc.fontSize(10).text(`Range: ${payload.range.from} - ${payload.range.to}`);
  doc.text(`Branch: ${payload.branch_id ?? 'ALL'}`);
  doc.moveDown();

  doc.fontSize(12).text('Totals', { underline: true });
  doc.fontSize(10);
  doc.text(`Orders: ${payload.totals.orders}`);
  doc.text(`Subtotal: ${payload.totals.subtotal}`);
  doc.text(`Discount: ${payload.totals.discount}`);
  doc.text(`Tax: ${payload.totals.tax}`);
  doc.text(`Total: ${payload.totals.total}`);
  doc.moveDown();

  doc.fontSize(12).text('Orders', { underline: true });
  doc.moveDown(0.5);

  const headerY = doc.y;
  doc.fontSize(9).text('Paid At', 40, headerY);
  doc.text('Order', 140, headerY);
  doc.text('Branch', 260, headerY);
  doc.text('Total', 420, headerY, { width: 120, align: 'right' });
  doc.moveDown();
  doc.moveTo(40, doc.y).lineTo(555, doc.y).stroke();

  doc.fontSize(9);
  for (const o of payload.orders) {
    const y = doc.y + 4;
    const paidAt = typeof o.paidAt === 'string' ? o.paidAt : o.paidAt?.toISOString?.() ?? '';
    doc.text(paidAt, 40, y, { width: 95 });
    doc.text(o.orderNumber, 140, y, { width: 110 });
    doc.text(o.branchId, 260, y, { width: 140 });
    doc.text(String(o.total), 420, y, { width: 120, align: 'right' });
    doc.moveDown(0.6);
    if (doc.y > 760) {
      doc.addPage();
    }
  }

  return doc;
}

export async function buildProfitLossExcel(payload: {
  branch_id: string | null;
  range: { from: string; to: string };
  totals: {
    revenue: number;
    cost: number;
    gross_profit: number;
    margin_percent: number;
  };
  items: Array<{
    medicine_name: string;
    qty: number;
    revenue: number;
    cost: number;
    gross_profit: number;
  }>;
}) {
  const wb = new ExcelJS.Workbook();
  const ws = wb.addWorksheet('ProfitLoss');

  ws.addRow(['Laporan Laba Rugi']);
  ws.addRow([`Periode: ${payload.range.from} - ${payload.range.to}`]);
  ws.addRow([`Cabang: ${payload.branch_id ?? 'SEMUA'}`]);
  ws.addRow([]);
  ws.addRow(['Pendapatan', payload.totals.revenue]);
  ws.addRow(['HPP', payload.totals.cost]);
  ws.addRow(['Laba kotor', payload.totals.gross_profit]);
  ws.addRow(['Margin %', payload.totals.margin_percent]);
  ws.addRow([]);
  ws.addRow(['Obat', 'Qty', 'Pendapatan', 'HPP', 'Laba']);
  ws.getRow(ws.rowCount).font = { bold: true };

  for (const row of payload.items) {
    ws.addRow([
      row.medicine_name,
      row.qty,
      row.revenue,
      row.cost,
      row.gross_profit,
    ]);
  }

  ws.columns.forEach((c) => {
    c.width = 16;
  });

  return wb.xlsx.writeBuffer();
}

