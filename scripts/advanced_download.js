/**
 * MeliPet Advanced Downloader
 * Supports complex download scenarios with Puppeteer
 */

const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');

// Configuration from environment
const CONFIG = {
  url: process.env.TARGET_URL || '',
  customFilename: process.env.CUSTOM_FILENAME || '',
  waitSelector: process.env.WAIT_SELECTOR || '',
  clickSelector: process.env.CLICK_SELECTOR || '',
  waitTime: parseInt(process.env.WAIT_TIME || '30') * 1000,
  userAgent: process.env.USER_AGENT || 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  downloadPath: path.resolve('./downloads'),
  screenshotPath: path.resolve('./downloads'),
};

// Utility functions
const logger = {
  header: (msg) => console.log('\n' + '='.repeat(60) + '\n' + msg + '\n' + '='.repeat(60)),
  info: (msg) => console.log(`ℹ️  ${msg}`),
  success: (msg) => console.log(`✓ ${msg}`),
  warning: (msg) => console.log(`⚠️  ${msg}`),
  error: (msg) => console.log(`❌ ${msg}`),
  progress: (msg) => process.stdout.write(`\r${msg}`),
};

function formatBytes(bytes) {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

function getDownloadedFiles() {
  if (!fs.existsSync(CONFIG.downloadPath)) return [];
  
  const files = fs.readdirSync(CONFIG.downloadPath);
  return files.filter(f => 
    !f.endsWith('.png') && 
    !f.endsWith('.html') &&
    !f.endsWith('.json') &&
    !f.endsWith('.crdownload') && 
    !f.endsWith('.tmp')
  );
}

async function waitForDownload(maxWaitTime) {
  logger.info(`Waiting for download (max ${maxWaitTime/1000}s)...`);
  
  const startTime = Date.now();
  let lastFileCount = 0;
  
  while ((Date.now() - startTime) < maxWaitTime) {
    const files = getDownloadedFiles();
    
    if (files.length > lastFileCount) {
      lastFileCount = files.length;
      logger.success(`Found ${files.length} file(s): ${files.join(', ')}`);
    }
    
    if (files.length > 0) {
      // Check if download is complete (no .crdownload or .tmp files)
      const allFiles = fs.readdirSync(CONFIG.downloadPath);
      const inProgress = allFiles.filter(f => f.endsWith('.crdownload') || f.endsWith('.tmp'));
      
      if (inProgress.length === 0) {
        logger.success('Download completed!');
        return files;
      }
    }
    
    const elapsed = Math.round((Date.now() - startTime) / 1000);
    if (elapsed % 5 === 0 && elapsed > 0) {
      logger.progress(`   Waiting... (${elapsed}s elapsed)`);
    }
    
    await new Promise(r => setTimeout(r, 1000));
  }
  
  return getDownloadedFiles();
}

async function findDownloadLinks(page) {
  logger.info('Searching for download links...');
  
  const links = await page.evaluate(() => {
    const anchors = Array.from(document.querySelectorAll('a[href]'));
    return anchors
      .filter(a => {
        const href = a.href.toLowerCase();
        const text = a.textContent.toLowerCase();
        return href.includes('download') || 
               text.includes('download') ||
               href.match(/\.(jar|zip|exe|apk|pdf|tar|gz|7z|rar|deb|rpm|dmg|pkg)$/);
      })
      .map(a => ({ 
        href: a.href, 
        text: a.textContent.trim(),
        classes: a.className 
      }))
      .slice(0, 20);
  });
  
  if (links.length > 0) {
    logger.success(`Found ${links.length} potential download links:`);
    links.forEach((link, i) => {
      console.log(`  ${i+1}. ${link.text}`);
      console.log(`     ${link.href}`);
    });
    
    fs.writeFileSync(
      path.join(CONFIG.downloadPath, 'found_links.json'), 
      JSON.stringify(links, null, 2)
    );
  } else {
    logger.warning('No download links found');
  }
  
  return links;
}

async function saveMetadata(files, startTime) {
  const metadata = {
    url: CONFIG.url,
    timestamp: new Date().toISOString(),
    duration: Math.round((Date.now() - startTime) / 1000),
    files: files.map(f => {
      const filePath = path.join(CONFIG.downloadPath, f);
      const stats = fs.statSync(filePath);
      return {
        name: f,
        size: stats.size,
        sizeFormatted: formatBytes(stats.size),
        modified: stats.mtime.toISOString()
      };
    }),
    config: {
      customFilename: CONFIG.customFilename || null,
      waitSelector: CONFIG.waitSelector || null,
      clickSelector: CONFIG.clickSelector || null,
      waitTime: CONFIG.waitTime / 1000,
      userAgent: CONFIG.userAgent
    }
  };
  
  fs.writeFileSync(
    path.join(CONFIG.downloadPath, 'metadata.json'), 
    JSON.stringify(metadata, null, 2)
  );
  
  logger.success('Metadata saved');
}

async function main() {
  const startTime = Date.now();
  
  logger.header('🚀 MeliPet Advanced Downloader');
  logger.info(`Target URL: ${CONFIG.url}`);
  logger.info(`Wait time: ${CONFIG.waitTime/1000}s`);
  if (CONFIG.customFilename) logger.info(`Custom filename: ${CONFIG.customFilename}`);
  if (CONFIG.waitSelector) logger.info(`Wait selector: ${CONFIG.waitSelector}`);
  if (CONFIG.clickSelector) logger.info(`Click selector: ${CONFIG.clickSelector}`);
  
  // Create download directory
  if (!fs.existsSync(CONFIG.downloadPath)) {
    fs.mkdirSync(CONFIG.downloadPath, { recursive: true });
  }
  
  // Launch browser
  logger.info('Launching browser...');
  const browser = await puppeteer.launch({
    headless: 'new',
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-accelerated-2d-canvas',
      '--disable-gpu',
      '--window-size=1920,1080',
      '--disable-web-security',
      '--disable-features=IsolateOrigins,site-per-process'
    ]
  });
  
  const page = await browser.newPage();
  
  // Set user agent
  await page.setUserAgent(CONFIG.userAgent);
  await page.setViewport({ width: 1920, height: 1080 });
  
  // Configure download behavior
  await page._client().send('Page.setDownloadBehavior', {
    behavior: 'allow',
    downloadPath: CONFIG.downloadPath
  });
  
  // Track network requests
  const downloadRequests = [];
  page.on('response', async (response) => {
    const url = response.url();
    const contentType = response.headers()['content-type'] || '';
    const contentDisposition = response.headers()['content-disposition'] || '';
    
    if (contentDisposition.includes('attachment') || 
        contentType.includes('application/') ||
        contentType.includes('octet-stream')) {
      logger.info(`Detected download: ${url}`);
      downloadRequests.push({ url, contentType, contentDisposition });
    }
  });
  
  // Navigate to page
  logger.info('Opening page...');
  try {
    await page.goto(CONFIG.url, {
      waitUntil: 'networkidle2',
      timeout: 90000
    });
    logger.success('Page loaded');
  } catch (e) {
    logger.warning(`Page load timeout: ${e.message}`);
  }
  
  // Take initial screenshot
  await page.screenshot({ 
    path: path.join(CONFIG.screenshotPath, 'page_initial.png'),
    fullPage: false 
  });
  logger.success('Initial screenshot saved');
  
  // Wait for specific selector
  if (CONFIG.waitSelector) {
    logger.info(`Waiting for selector: ${CONFIG.waitSelector}`);
    try {
      await page.waitForSelector(CONFIG.waitSelector, { timeout: 30000 });
      logger.success('Selector found');
    } catch (e) {
      logger.warning('Selector not found, continuing anyway...');
    }
  }
  
  // Click download button
  if (CONFIG.clickSelector) {
    logger.info(`Clicking selector: ${CONFIG.clickSelector}`);
    try {
      await page.waitForSelector(CONFIG.clickSelector, { timeout: 10000 });
      await page.click(CONFIG.clickSelector);
      logger.success('Clicked successfully');
      
      await page.screenshot({ 
        path: path.join(CONFIG.screenshotPath, 'page_after_click.png'),
        fullPage: false 
      });
    } catch (e) {
      logger.warning(`Could not click selector: ${e.message}`);
    }
  }
  
  // Wait for download
  const downloadedFiles = await waitForDownload(CONFIG.waitTime);
  
  // If no files downloaded, search for links
  if (downloadedFiles.length === 0) {
    logger.warning('No automatic download detected');
    logger.info('Taking final screenshot...');
    await page.screenshot({ 
      path: path.join(CONFIG.screenshotPath, 'page_final.png'),
      fullPage: true 
    });
    
    await findDownloadLinks(page);
  }
  
  // Save page HTML
  const html = await page.content();
  fs.writeFileSync(path.join(CONFIG.downloadPath, 'page.html'), html);
  logger.success('Page HTML saved');
  
  await browser.close();
  
  // Display results
  const allFiles = fs.readdirSync(CONFIG.downloadPath);
  logger.header('📁 Files in download folder:');
  allFiles.forEach(f => {
    const stats = fs.statSync(path.join(CONFIG.downloadPath, f));
    console.log(`   ${f} (${formatBytes(stats.size)})`);
  });
  
  // Save metadata
  if (downloadedFiles.length > 0) {
    await saveMetadata(downloadedFiles, startTime);
  }
  
  const elapsed = Math.round((Date.now() - startTime) / 1000);
  logger.header(`✅ Completed in ${elapsed}s`);
  
  process.exit(downloadedFiles.length > 0 ? 0 : 1);
}

// Run
main().catch(err => {
  logger.error(`Fatal error: ${err.message}`);
  console.error(err);
  process.exit(1);
});
