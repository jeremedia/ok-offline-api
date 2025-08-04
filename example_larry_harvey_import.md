# How to Add Larry Harvey's Writings to the Enliterated Dataset

## 📁 Step 1: Organize Your Text Files

Create a directory structure like this:

```
/Users/jeremy/larry_harvey_writings/
├── ten_principles_2004.txt
├── burning_man_philosophy.md
├── speech_temple_dedication_2005.txt
├── manifesto_gift_economy.txt
├── letter_to_community_2010.md
└── essays/
    ├── art_and_community_2003.txt
    └── radical_self_expression_2007.txt
```

## 📝 Step 2: Format Your Text Files

### Simple Text File Example:
**File:** `ten_principles_2004.txt`
```
The Ten Principles of Burning Man

Radical Inclusion: Anyone may be a part of Burning Man. We welcome and respect the stranger. No prerequisites exist for participation in our community.

Gifting: Burning Man is devoted to acts of gift giving. The value of a gift is unconditional. Gifting does not contemplate a return or an exchange for something of equal value.

Decommodification: In order to preserve the spirit of gifting, our community seeks to create social environments that are unmediated by commercial sponsorships, transactions, or advertising.

[... rest of content ...]
```

### With YAML Metadata (Optional):
**File:** `speech_temple_dedication_2005.txt`
```yaml
---
title: "Temple Dedication Speech"
year: 2005
type: speech
event: "Temple Dedication Ceremony"
location: "Black Rock City"
---

My fellow Burners, we gather today to dedicate this sacred space...

[... speech content ...]
```

## 🚀 Step 3: Import Using Rails Task

```bash
# Preview what will be imported (dry run)
DRY_RUN=true rails biographical:import["/Users/jeremy/larry_harvey_writings","Larry Harvey"]

# Actually import the files
AUTHOR_ID=person:larry_harvey rails biographical:import["/Users/jeremy/larry_harvey_writings","Larry Harvey"]

# With custom default year
DEFAULT_YEAR=2010 rails biographical:import["/Users/jeremy/larry_harvey_writings","Larry Harvey"]
```

## 🧪 Step 4: Test the Results

```bash
# Test the persona style with new content
rails biographical:test_persona["Larry Harvey"]

# List all biographical content
rails biographical:list

# Rebuild the persona cache
rails biographical:rebuild_persona["Larry Harvey"]
```

## 🔍 What Happens During Import

1. **File Processing**: Each text file is read and analyzed
2. **Metadata Extraction**: Title, year, type auto-detected from filename/content
3. **Item Type Classification**: 
   - `philosophical_text` - Contains "principle", philosophy
   - `speech` - Filename has "speech" or "address"  
   - `essay` - General writings
   - `manifesto` - Statements, manifestos
   - `interview` - Q&A format content
4. **Unique ID Generation**: `biographical_larry_harvey_ten_principles_2004`
5. **Embedding Generation**: Full content vectorized with `text-embedding-3-small`
6. **Entity Extraction**: People, places, concepts, Burning Man terms
7. **Seven Pools Classification**: Content automatically categorized into Idea, Emanation, etc.

## 📊 Expected Results After Import

**Before Import (Current State):**
```
persona_id=person:larry_harvey
style_confidence=0.32
sources_count=2
pools_covered=relational, practical
```

**After Import (Expected):**
```
persona_id=person:larry_harvey  
style_confidence=0.85+
sources_count=15+
pools_covered=idea, emanation, manifest, experience, practical
```

## 🎯 Content Types That Boost Confidence

### High Impact (Idea + Emanation Pools):
- **Ten Principles** documents
- **Philosophical essays** on Burning Man values
- **Manifestos** about gift economy, decommodification
- **Founding stories** and origin narratives

### Medium Impact (Manifest + Experience Pools):
- **Speeches** from official events
- **Letters** to the community
- **Interviews** about Burning Man philosophy
- **Program notes** for events

### Supporting Content:
- **Personal reflections** on community
- **Art installation** descriptions he authored
- **Policy statements** on Burning Man principles

## 🔧 File Naming Best Practices

- Include **year**: `speech_2004.txt` or `essay_gift_economy_2007.md`
- Use **descriptive names**: `ten_principles_complete.txt`
- Include **content type**: `manifesto_decommodification.txt`
- Keep **author consistent**: All files should be Larry Harvey's writings

## 💡 Pro Tips

1. **YAML Front Matter**: Add metadata for better classification
2. **Full Content**: Include complete text, not just excerpts
3. **Chronological Order**: Year detection helps with era filtering
4. **Rights Awareness**: Mark any content requiring special attribution
5. **Test Frequently**: Run `biographical:test_persona` after each batch

## 🎨 Integration with Persona Style

Once imported, the enlarged corpus will:
- ✅ **Increase confidence** from 0.32 to 0.70+ 
- ✅ **Expand vocabulary** with Larry Harvey's actual words
- ✅ **Capture rhetorical devices** (triads, imperatives, etc.)
- ✅ **Enable quotable responses** with proper attribution
- ✅ **Support era filtering** (early vs. late period writing)
- ✅ **Cross-pool bridging** between philosophy and practice

The MCP agent will then be able to write **"in the style of Larry Harvey"** with high confidence, proper attribution, and authentic voice characteristics derived from his actual writings.