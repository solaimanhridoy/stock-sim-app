const fs = require('fs');
const path = require('path');
const pool = require('../src/db/pool');

async function main() {
  const client = await pool.connect();
  try {
    console.log('--- Loading stock data ---');
    const csvPath = path.join(__dirname, '../data/stock_market/DSE_STOCKS_merged_final_ordered - Copy.csv');
    
    const stocks = new Set();
    const prices = [];

    const fileStream = fs.createReadStream(csvPath);
    const rl = require('readline').createInterface({
      input: fileStream,
      crlfDelay: Infinity
    });

    let isHeader = true;
    for await (const line of rl) {
      if (isHeader) { isHeader = false; continue; }
      
      const [ticker, open, high, low, close, volume, date] = line.split(',');
      if (!ticker || ticker === '') continue;
      
      stocks.add(ticker);
      prices.push({
        ticker,
        open: parseFloat(open),
        high: parseFloat(high),
        low: parseFloat(low),
        close: parseFloat(close),
        volume: parseInt(volume, 10),
        date: date.trim()
      });
    }

    console.log(`Found ${stocks.size} unique stocks and ${prices.length} price records.`);

    await client.query('BEGIN');

    // 1. Insert Stocks
    for (const ticker of stocks) {
      await client.query(
        `INSERT INTO stocks (ticker, company_name, sector) 
         VALUES ($1, $2, $3) 
         ON CONFLICT (ticker) DO NOTHING`,
        [ticker, `${ticker} Corp`, 'General']
      );
    }
    console.log('Stocks processed.');

    // 2. Insert Prices
    for (const price of prices) {
      await client.query(
        `INSERT INTO prices (date, ticker, open, high, low, close, volume)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         ON CONFLICT (date, ticker) DO NOTHING`,
        [price.date, price.ticker, price.open, price.high, price.low, price.close, price.volume]
      );
    }

    await client.query('COMMIT');
    console.log('Prices populated successfully!');

  } catch (err) {
    console.error('Error during seeding:', err);
  } finally {
    client.release();
    pool.end();
  }
}

main();
