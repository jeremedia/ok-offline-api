#!/usr/bin/env node

// Larry Harvey Content Fetcher using Playwright
// Usage: node fetch_larry_harvey_playwright.js

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const OUTPUT_DIR = 'larry_harvey_writings';

// Priority 1 URLs - Core philosophical texts
const PRIORITY_1_URLS = [
  {
    url: 'https://burningman.org/about/10-principles/',
    filename: 'ten_principles_2004.txt',
    title: 'The Ten Principles of Burning Man',
    year: 2004,
    type: 'philosophical_text'
  },
  {
    url: 'https://journal.burningman.org/2013/11/philosophical-center/tenprinciples/introduction-the-philosophical-center/',
    filename: 'philosophical_center_introduction_2013.txt',
    title: 'Introduction: The Philosophical Center',
    year: 2013,
    type: 'philosophical_text'
  },
  {
    url: 'https://journal.burningman.org/2013/11/philosophical-center/tenprinciples/commerce-community-distilling-philosophy-from-a-cup-of-coffee/',
    filename: 'commerce_community_2013.txt',
    title: 'Commerce & Community: Distilling philosophy from a cup of coffee',
    year: 2013,
    type: 'philosophical_text'
  },
  {
    url: 'https://journal.burningman.org/2019/06/philosophical-center/tenprinciples/a-guide-to-gifting-givers-and-gratitude-a-treatise-from-the-philosophical-center/',
    filename: 'guide_to_gifting_2019.txt',
    title: 'A Guide to Gifting, Givers and Gratitude',
    year: 2019,
    type: 'philosophical_text'
  },
  {
    url: 'https://journal.burningman.org/2013/11/philosophical-center/tenprinciples/how-the-west-was-won-anarchy-vs-civic-responsibility/',
    filename: 'how_west_was_won_2013.txt',
    title: 'How the West Was Won: Anarchy vs. Civic Responsibility',
    year: 2013,
    type: 'essay'
  }
];

async function fetchUrlContent(page, url) {
  console.log(`🎭 Fetching: ${url}`);
  
  try {
    // Navigate to the URL
    await page.goto(url, { 
      waitUntil: 'networkidle',
      timeout: 30000 
    });
    
    // Wait for content to load
    await page.waitForTimeout(2000);
    
    // Get visible text content, excluding navigation
    const content = await page.evaluate(() => {
      // Remove script and style elements
      const scripts = document.querySelectorAll('script, style, nav, header, footer');
      scripts.forEach(el => el.remove());
      
      // Find main content area
      const contentSelectors = [
        'article',
        '.entry-content', 
        '.post-content',
        '.content',
        'main',
        '.main-content',
        '#content'
      ];
      
      let mainContent = null;
      for (const selector of contentSelectors) {
        const element = document.querySelector(selector);
        if (element && element.innerText.length > 500) {
          mainContent = element;
          break;
        }
      }
      
      // Fallback to body if no main content found
      if (!mainContent) {
        mainContent = document.body;
      }
      
      return mainContent.innerText;
    });
    
    if (content && content.length > 200) {
      console.log(`  ✓ Extracted ${content.length} characters`);
      return content;
    } else {
      console.log(`  ❌ No substantial content found`);
      return null;
    }
    
  } catch (error) {
    console.log(`  ❌ Error: ${error.message}`);
    return null;
  }
}

function cleanContent(rawContent) {
  if (!rawContent || rawContent.length < 200) return null;
  
  let content = rawContent;
  
  // Remove common navigation and UI elements
  const noisePatterns = [
    /Skip to (?:main )?content/gi,
    /Menu\s*/gi,
    /Navigation/gi,
    /Search\s*/gi,
    /Home\s+About\s+/gi,
    /Subscribe\s*/gi,
    /Share this/gi,
    /Print\s*/gi,
    /Email\s*/gi,
    /Facebook\s+Twitter\s*/gi,
    /← Previous\s+Next →/gi,
    /Related Posts/gi,
    /Comments/gi,
    /Tags:/gi
  ];
  
  noisePatterns.forEach(pattern => {
    content = content.replace(pattern, '');
  });
  
  // Clean up whitespace
  content = content
    .trim()
    .replace(/\n\s*\n\s*\n+/g, '\n\n')  // Multiple newlines to double
    .replace(/[ \t]+/g, ' ')             // Multiple spaces to single
    .replace(/^\s+/gm, '');              // Leading whitespace on lines
  
  // Remove very short lines that are likely navigation
  const lines = content.split('\n');
  const filteredLines = lines.filter(line => {
    const trimmed = line.trim();
    return trimmed.length === 0 || 
           trimmed.length > 10 || 
           /^[A-Z]/.test(trimmed); // Keep capitalized short lines (headings)
  });
  
  content = filteredLines.join('\n');
  
  return content.length > 500 ? content : null;
}

function createTextFile(content, metadata, outputDir) {
  if (!content || content.length < 500) return false;
  
  const filepath = path.join(outputDir, metadata.filename);
  
  const yamlHeader = `---
title: "${metadata.title}"
year: ${metadata.year}
type: ${metadata.type}
author: Larry Harvey
source_url: "${metadata.url}"
fetched_at: "${new Date().toISOString().split('T')[0]} ${new Date().toTimeString().split(' ')[0]}"
word_count: ${content.split(/\s+/).length}
---

`;
  
  const fullContent = yamlHeader + content;
  
  try {
    fs.writeFileSync(filepath, fullContent, 'utf8');
    console.log(`  ✓ Created: ${metadata.filename} (${content.split(/\s+/).length} words)`);
    return true;
  } catch (error) {
    console.log(`  ❌ Failed to write file: ${error.message}`);
    return false;
  }
}

async function main() {
  console.log('🎭 Larry Harvey Content Fetcher (Playwright)');
  console.log('='.repeat(60));
  
  // Create output directory
  if (!fs.existsSync(OUTPUT_DIR)) {
    fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  }
  
  console.log(`📁 Output directory: ${path.resolve(OUTPUT_DIR)}`);
  console.log('');
  
  // Launch browser
  console.log('🚀 Launching Chromium browser...');
  const browser = await chromium.launch({ 
    headless: true,
    timeout: 60000
  });
  
  const context = await browser.newContext({
    userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
  });
  
  const page = await context.newPage();
  
  let successCount = 0;
  
  for (let i = 0; i < PRIORITY_1_URLS.length; i++) {
    const item = PRIORITY_1_URLS[i];
    console.log(`[${i + 1}/${PRIORITY_1_URLS.length}] ${item.title}`);
    
    // Skip if file already exists
    const filepath = path.join(OUTPUT_DIR, item.filename);
    if (fs.existsSync(filepath)) {
      console.log(`  ⏭️  Already exists: ${item.filename}`);
      continue;
    }
    
    // Fetch content
    const rawContent = await fetchUrlContent(page, item.url);
    if (!rawContent) continue;
    
    // Clean content
    const cleanedContent = cleanContent(rawContent);
    if (!cleanedContent) continue;
    
    // Create file
    if (createTextFile(cleanedContent, item, OUTPUT_DIR)) {
      successCount++;
    }
    
    // Rate limiting - be nice to servers
    await page.waitForTimeout(2000);
  }
  
  // Close browser
  console.log('');
  console.log('🎭 Closing browser...');
  await browser.close();
  
  console.log('');
  console.log('📊 Results:');
  console.log(`   ✅ Successfully created: ${successCount} files`);
  console.log(`   ❌ Failed: ${PRIORITY_1_URLS.length - successCount}`);
  
  if (successCount > 0) {
    console.log('');
    console.log('🚀 Next steps:');
    console.log(`   rails biographical:import['${path.resolve(OUTPUT_DIR)}','Larry Harvey']`);
    console.log(`   rails biographical:test_persona['Larry Harvey']`);
  }
}

// Run the script
if (require.main === module) {
  main().catch(error => {
    console.error('❌ Script failed:', error);
    process.exit(1);
  });
}