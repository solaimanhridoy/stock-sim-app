/**
 * build_stock_master.js
 * 
 * Data-scientist + backend-engineer pipeline:
 * 1. Reads all daily CSV files from data/stock_market/data(99-23)/2023/
 * 2. Identifies top 30 most-traded DSE stocks (by total volume)
 * 3. Seeds `stocks` table with real company names & sectors
 * 4. Seeds `prices` table with full 2023 daily candle data for those 30 stocks
 * 
 * Run: node scripts/build_stock_master.js
 */

const fs = require('fs');
const path = require('path');
const readline = require('readline');
const pool = require('../src/db/pool');

// ══════════════════════════════════════════════════════════════════════
// DSE Stock Master — Real company names & sectors for top BD stocks
// ══════════════════════════════════════════════════════════════════════
const DSE_STOCK_MASTER = {
  'BEXIMCO':      { name: 'Beximco Limited', sector: 'Pharmaceuticals & Chemicals' },
  'SQURPHARMA':   { name: 'Square Pharmaceuticals Ltd.', sector: 'Pharmaceuticals & Chemicals' },
  'GP':           { name: 'Grameenphone Ltd.', sector: 'Telecommunication' },
  'RENATA':       { name: 'Renata Limited', sector: 'Pharmaceuticals & Chemicals' },
  'BXPHARMA':     { name: 'Beximco Pharmaceuticals Ltd.', sector: 'Pharmaceuticals & Chemicals' },
  'ICB':          { name: 'Investment Corporation of Bangladesh', sector: 'Financial Institutions' },
  'BRACBANK':     { name: 'BRAC Bank Limited', sector: 'Bank' },
  'ISLAMIBANK':   { name: 'Islami Bank Bangladesh Ltd.', sector: 'Bank' },
  'DUTCHBANGL':   { name: 'Dutch-Bangla Bank Limited', sector: 'Bank' },
  'CITYBANK':     { name: 'The City Bank Limited', sector: 'Bank' },
  'BERGERPBL':    { name: 'Berger Paints Bangladesh Ltd.', sector: 'Cement & Chemicals' },
  'MARICO':       { name: 'Marico Bangladesh Limited', sector: 'Pharmaceuticals & Chemicals' },
  'OLYMPIC':      { name: 'Olympic Industries Limited', sector: 'Food & Allied' },
  'BATBC':        { name: 'British American Tobacco Bangladesh', sector: 'Food & Allied' },
  'UPGDCL':       { name: 'United Power Generation & Dist. Co.', sector: 'Power & Fuel' },
  'WALTONHIL':    { name: 'Walton Hi-Tech Industries Ltd.', sector: 'Engineering' },
  'LHBL':         { name: 'LafargeHolcim Bangladesh Ltd.', sector: 'Cement' },
  'SUMITPOWER':   { name: 'Summit Power Limited', sector: 'Power & Fuel' },
  'EBL':          { name: 'Eastern Bank Limited', sector: 'Bank' },
  'PUBALIBANK':   { name: 'Pubali Bank Limited', sector: 'Bank' },
  'ACMELAB':      { name: 'ACME Laboratories Limited', sector: 'Pharmaceuticals & Chemicals' },
  'ACI':          { name: 'Advanced Chemical Industries Ltd.', sector: 'Pharmaceuticals & Chemicals' },
  'ORIONPHARM':   { name: 'Orion Pharma Limited', sector: 'Pharmaceuticals & Chemicals' },
  'POWERGRID':    { name: 'Power Grid Company of Bangladesh', sector: 'Power & Fuel' },
  'ROBI':         { name: 'Robi Axiata Limited', sector: 'Telecommunication' },
  'DELTALIFE':    { name: 'Delta Life Insurance Co. Ltd.', sector: 'Insurance' },
  'ABBANK':       { name: 'AB Bank Limited', sector: 'Bank' },
  'LANKABAFIN':   { name: 'LankaBangla Finance Limited', sector: 'Financial Institutions' },
  'ADNTEL':       { name: 'ADN Telecom Limited', sector: 'Telecommunication' },
  'AAMRANET':     { name: 'Aamra Networks Limited', sector: 'IT & Telecommunication' },
  'ACFL':         { name: 'Asian Consumer Finance Ltd.', sector: 'Financial Institutions' },
  'ACIFORMULA':   { name: 'ACI Formulations Limited', sector: 'Pharmaceuticals & Chemicals' },
  'ACMEPL':       { name: 'ACME Pesticides Limited', sector: 'Pharmaceuticals & Chemicals' },
  'ADVENT':       { name: 'Advent Pharma Limited', sector: 'Pharmaceuticals & Chemicals' },
  'AGNISYSL':     { name: 'Agni Systems Limited', sector: 'IT' },
  'AFTABAUTO':    { name: 'Aftab Automobiles Ltd.', sector: 'Engineering' },
  'ALLTEX':       { name: 'Alltex Industries Limited', sector: 'Textile' },
  'AMANFEED':     { name: 'Aman Feed Limited', sector: 'Food & Allied' },
  'AMBEEPHA':     { name: 'Ambee Pharmaceuticals Limited', sector: 'Pharmaceuticals & Chemicals' },
  'APEXFOOT':     { name: 'Apex Footwear Limited', sector: 'Tannery' },
  'APEXFOODS':    { name: 'Apex Foods Limited', sector: 'Food & Allied' },
  'APEXSPINN':    { name: 'Apex Spinning & Knitting Mills', sector: 'Textile' },
  'APOLOISPAT':   { name: 'Apolo Ispat Complex Limited', sector: 'Engineering' },
  'AZIZPIPES':    { name: 'Aziz Pipes Limited', sector: 'Engineering' },
  'BANKASIA':     { name: 'Bank Asia Limited', sector: 'Bank' },
  'BDCOM':        { name: 'BDCOM Online Limited', sector: 'IT' },
  'BSRMSTEEL':    { name: 'BSRM Steels Limited', sector: 'Engineering' },
  'DESCO':        { name: 'Dhaka Electric Supply Company', sector: 'Power & Fuel' },
  'DHAKABANK':    { name: 'Dhaka Bank Limited', sector: 'Bank' },
  'DSEX':         { name: 'DSE Broad Index', sector: 'Index' },
  'EXCELCROP':    { name: 'Excel Crop Care Limited', sector: 'Pharmaceuticals & Chemicals' },
  'TRUSTBANK':    { name: 'Trust Bank Limited', sector: 'Bank' },
  // Fallback — any ticker not in this map gets a generated name
};

// ══════════════════════════════════════════════════════════════════════
// INDEX TICKERS to exclude (these are indices, not tradable stocks)
// ══════════════════════════════════════════════════════════════════════
const INDEX_TICKERS = new Set([
  '00DS30', '00DSES', '00DSEX', 'DSEX', 'DS30', 'DSES',
]);

async function main() {
  const dataDir = path.join(__dirname, '..', 'data', 'stock_market', 'data(99-23)', '2023');
  const files = fs.readdirSync(dataDir).filter(f => f.endsWith('.csv')).sort();

  console.log(`📁 Found ${files.length} daily CSV files in 2023 directory`);

  // ── Step 1: Aggregate all data ──────────────────────────────────
  // ticker -> { totalVolume, dates: { date -> { open, high, low, close, volume } } }
  const tickerData = {};

  for (const file of files) {
    const filePath = path.join(dataDir, file);
    const rl = readline.createInterface({
      input: fs.createReadStream(filePath),
      crlfDelay: Infinity,
    });

    let isHeader = true;
    for await (const line of rl) {
      if (isHeader) { isHeader = false; continue; }

      // Format: Date,Scrip,Open,High,Low,Close,Volume
      const parts = line.split(',');
      if (parts.length < 7) continue;

      const [rawDate, ticker, open, high, low, close, volume] = parts;
      if (!ticker || INDEX_TICKERS.has(ticker)) continue;

      const parsedOpen = parseFloat(open);
      const parsedClose = parseFloat(close);
      const parsedHigh = parseFloat(high);
      const parsedLow = parseFloat(low);
      const parsedVolume = parseInt(volume, 10);

      // Skip invalid data
      if (isNaN(parsedClose) || parsedClose <= 0 || isNaN(parsedVolume)) continue;

      // Normalize date: 20230101 -> 2023-01-01
      const dateStr = rawDate.length === 8
        ? `${rawDate.slice(0, 4)}-${rawDate.slice(4, 6)}-${rawDate.slice(6, 8)}`
        : rawDate;

      if (!tickerData[ticker]) {
        tickerData[ticker] = { totalVolume: 0, records: [] };
      }

      tickerData[ticker].totalVolume += (parsedVolume || 0);
      tickerData[ticker].records.push({
        date: dateStr,
        open: parsedOpen,
        high: parsedHigh,
        low: parsedLow,
        close: parsedClose,
        volume: parsedVolume || 0,
      });
    }
  }

  const allTickers = Object.keys(tickerData);
  console.log(`📊 Total unique tickers found: ${allTickers.length}`);

  // ── Step 2: Pick top 30 by total volume ──────────────────────────
  const ranked = allTickers
    .map(t => ({ ticker: t, totalVolume: tickerData[t].totalVolume, recordCount: tickerData[t].records.length }))
    .sort((a, b) => b.totalVolume - a.totalVolume);

  const TOP_N = 30;
  const topStocks = ranked.slice(0, TOP_N);

  console.log(`\n🏆 Top ${TOP_N} stocks by trading volume:`);
  topStocks.forEach((s, i) => {
    const info = DSE_STOCK_MASTER[s.ticker];
    console.log(`  ${String(i + 1).padStart(2)}. ${s.ticker.padEnd(15)} Vol: ${s.totalVolume.toLocaleString().padStart(15)}  Days: ${s.recordCount}  ${info ? info.name : '(unmapped)'}`);
  });

  // ── Step 3: Seed database ──────────────────────────────────────
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Clear existing data for clean re-seed
    console.log('\n🗑️  Clearing existing stock & price data...');
    await client.query('DELETE FROM transactions');
    await client.query('DELETE FROM portfolios');
    await client.query('DELETE FROM prices');
    await client.query('DELETE FROM stocks');

    // Insert stocks
    console.log('📝 Inserting stock master...');
    for (const stock of topStocks) {
      const info = DSE_STOCK_MASTER[stock.ticker] || {
        name: `${stock.ticker} Ltd.`,
        sector: 'General',
      };
      await client.query(
        `INSERT INTO stocks (ticker, company_name, sector, is_active)
         VALUES ($1, $2, $3, TRUE)
         ON CONFLICT (ticker) DO UPDATE SET company_name = $2, sector = $3`,
        [stock.ticker, info.name, info.sector]
      );
    }

    // Insert prices
    console.log('📈 Inserting price data...');
    let priceCount = 0;
    for (const stock of topStocks) {
      const records = tickerData[stock.ticker].records;
      for (const rec of records) {
        await client.query(
          `INSERT INTO prices (date, ticker, open, high, low, close, volume)
           VALUES ($1, $2, $3, $4, $5, $6, $7)
           ON CONFLICT (date, ticker) DO NOTHING`,
          [rec.date, stock.ticker, rec.open, rec.high, rec.low, rec.close, rec.volume]
        );
        priceCount++;
      }
    }

    await client.query('COMMIT');
    console.log(`\n✅ Seeded ${topStocks.length} stocks with ${priceCount} price records`);

    // Show date range
    const dateRange = await client.query('SELECT MIN(date) as first, MAX(date) as last, COUNT(DISTINCT date) as days FROM prices');
    const r = dateRange.rows[0];
    console.log(`📅 Date range: ${r.first} → ${r.last} (${r.days} trading days)`);

  } catch (err) {
    await client.query('ROLLBACK');
    console.error('❌ Error:', err);
    throw err;
  } finally {
    client.release();
    await pool.end();
  }
}

main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
