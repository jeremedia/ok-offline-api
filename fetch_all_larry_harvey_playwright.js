#!/usr/bin/env node

// Complete Larry Harvey Content Fetcher using Playwright
// Fetches all essays from the comprehensive catalog
// Usage: node fetch_all_larry_harvey_playwright.js [priority]

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const OUTPUT_DIR = 'larry_harvey_writings';
const METADATA_FILE = 'all_larry_harvey_urls_with_metadata.txt';

function parseMetadataFile() {
  if (!fs.existsSync(METADATA_FILE)) {
    console.error(`❌ Metadata file not found: ${METADATA_FILE}`);
    process.exit(1);
  }
  
  const content = fs.readFileSync(METADATA_FILE, 'utf8');
  const lines = content.split('\n').filter(line => line.trim() && !line.startsWith('Journal') && !line.startsWith('Art Theme') && !line.startsWith('Other Major'));
  
  const urls = [];
  
  lines.forEach(line => {
    const parts = line.split(' | ');
    if (parts.length >= 6) {
      urls.push({
        url: parts[0].trim(),
        filename: parts[1].trim(),
        title: parts[2].trim(),
        year: parseInt(parts[3].trim()),
        type: parts[4].trim(),
        priority: parseInt(parts[5].trim())
      });
    }
  });
  
  return urls;
}

async function fetchUrlContent(page, url) {
  console.log(`🎭 Fetching: ${url.substring(0, 80)}...`);
  
  try {
    // Navigate to the URL
    await page.goto(url, { 
      waitUntil: 'domcontentloaded',
      timeout: 45000 
    });
    
    // Wait for content to load
    await page.waitForTimeout(3000);
    
    // Get visible text content, excluding navigation
    const content = await page.evaluate(() => {
      // Remove script, style, and navigation elements
      const elementsToRemove = document.querySelectorAll(`
        script, style, nav, header, footer, aside,
        .navigation, .nav, .menu, .sidebar, .ads,
        .social-share, .comments, .related-posts,
        .breadcrumb, .tags, .categories, .metadata,
        [class*="nav"], [class*="menu"], [id*="nav"], [id*="menu"]
      `);
      elementsToRemove.forEach(el => el.remove());
      
      // Find main content area using multiple strategies
      const contentSelectors = [
        'article .entry-content',
        '.post-content',
        'article',
        '.entry-content', 
        '.content',
        'main',
        '.main-content',
        '#content',
        '.post',
        '.entry'
      ];
      
      let mainContent = null;
      let maxLength = 0;
      
      // Find the selector with the most content
      for (const selector of contentSelectors) {
        const element = document.querySelector(selector);
        if (element) {
          const text = element.innerText || '';
          if (text.length > maxLength && text.length > 300) {
            maxLength = text.length;
            mainContent = element;
          }
        }
      }
      
      // Fallback to body if no good content area found
      if (!mainContent || maxLength < 500) {
        mainContent = document.body;
      }
      
      return mainContent.innerText || '';
    });
    
    if (content && content.length > 300) {
      console.log(`  ✓ Extracted ${content.length} characters`);
      return content;
    } else {
      console.log(`  ❌ No substantial content found (${content ? content.length : 0} chars)`);
      return null;
    }
    
  } catch (error) {
    console.log(`  ❌ Error: ${error.message}`);
    return null;
  }
}

function cleanContent(rawContent, metadata) {
  if (!rawContent || rawContent.length < 300) return null;
  
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
    /Tags:/gi,
    /Categories:/gi,
    /Posted (?:on|in)/gi,
    /Read more/gi,
    /Continue reading/gi
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
    // Keep empty lines, substantial lines, or capitalized headings
    return trimmed.length === 0 || 
           trimmed.length > 15 || 
           (/^[A-Z]/.test(trimmed) && trimmed.length > 3);
  });
  
  content = filteredLines.join('\n');
  
  // Look for content that starts after common intro patterns
  const contentStartPatterns = [
    new RegExp(metadata.title.split(' ').slice(0, 3).join('\\s+'), 'i'),
    /By Larry Harvey/i,
    /Introduction/i,
    /Essay/i,
    /Theme/i
  ];
  
  for (const pattern of contentStartPatterns) {
    const match = content.match(pattern);
    if (match && match.index > 50 && match.index < content.length / 3) {
      content = content.substring(match.index);
      break;
    }
  }
  
  return content.length > 400 ? content : null;
}

function createTextFile(content, metadata, outputDir) {
  if (!content || content.length < 400) return false;
  
  const filepath = path.join(outputDir, metadata.filename);
  
  const yamlHeader = `---
title: "${metadata.title}"
year: ${metadata.year}
type: ${metadata.type}
author: Larry Harvey
source_url: "${metadata.url}"
fetched_at: "${new Date().toISOString().split('T')[0]} ${new Date().toTimeString().split(' ')[0]}"
word_count: ${content.split(/\s+/).length}
priority: ${metadata.priority}
---

`;
  
  const fullContent = yamlHeader + content;
  
  try {
    fs.writeFileSync(filepath, fullContent, 'utf8');
    const wordCount = content.split(/\s+/).length;
    console.log(`  ✓ Created: ${metadata.filename} (${wordCount} words)`);
    return true;
  } catch (error) {
    console.log(`  ❌ Failed to write file: ${error.message}`);
    return false;
  }
}

async function main() {
  const args = process.argv.slice(2);
  const maxPriority = args[0] ? parseInt(args[0]) : 3;
  
  console.log('🎭 Larry Harvey Complete Content Fetcher (Playwright)');
  console.log('='.repeat(70));
  
  // Parse metadata file
  const allUrls = parseMetadataFile();
  const urlsToFetch = allUrls.filter(item => item.priority <= maxPriority)
                           .sort((a, b) => a.priority - b.priority);
  
  console.log(`📊 Total URLs in catalog: ${allUrls.length}`);
  console.log(`🎯 Fetching priority 1-${maxPriority}: ${urlsToFetch.length} URLs`);
  
  // Show priority breakdown
  for (let p = 1; p <= 3; p++) {
    const count = urlsToFetch.filter(u => u.priority === p).length;
    if (count > 0) {
      const label = p === 1 ? 'Core philosophical texts' : 
                   p === 2 ? 'Essays and speeches' : 
                   'Theme essays and other';
      console.log(`   Priority ${p}: ${count} URLs (${label})`);
    }
  }
  
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
  let skippedCount = 0;
  
  for (let i = 0; i < urlsToFetch.length; i++) {
    const item = urlsToFetch[i];
    console.log(`[${i + 1}/${urlsToFetch.length}] P${item.priority} ${item.title} (${item.year})`);
    
    // Skip if file already exists
    const filepath = path.join(OUTPUT_DIR, item.filename);
    if (fs.existsSync(filepath)) {
      console.log(`  ⏭️  Already exists: ${item.filename}`);
      skippedCount++;
      continue;
    }
    
    // Fetch content
    const rawContent = await fetchUrlContent(page, item.url);
    if (!rawContent) continue;
    
    // Clean content
    const cleanedContent = cleanContent(rawContent, item);
    if (!cleanedContent) {
      console.log(`  ❌ Content too short after cleaning`);
      continue;
    }
    
    // Create file
    if (createTextFile(cleanedContent, item, OUTPUT_DIR)) {
      successCount++;
    }
    
    // Rate limiting - be respectful to servers
    await page.waitForTimeout(2500);
  }
  
  // Close browser
  console.log('');
  console.log('🎭 Closing browser...');
  await browser.close();
  
  console.log('');
  console.log('📊 Final Results:');
  console.log(`   ✅ Successfully created: ${successCount} files`);
  console.log(`   ⏭️  Already existed: ${skippedCount} files`);
  console.log(`   ❌ Failed: ${urlsToFetch.length - successCount - skippedCount}`);
  
  if (successCount > 0) {
    console.log('');
    console.log('🚀 Next steps:');
    console.log(`   rails biographical:import['${path.resolve(OUTPUT_DIR)}','Larry Harvey']`);
    console.log(`   rails biographical:test_persona['Larry Harvey']`);
    console.log('');
    console.log('💡 Expected transformation:');
    console.log('   Before: style_confidence=0.32, sources_count=2');
    console.log('   After:  style_confidence=0.75+, sources_count=15+');
  }
  
  console.log('');
  console.log('📝 Files created in:', path.resolve(OUTPUT_DIR));
}

// Run the script
if (require.main === module) {
  main().catch(error => {
    console.error('❌ Script failed:', error);
    process.exit(1);
  });
}