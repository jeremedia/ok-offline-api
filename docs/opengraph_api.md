# OpenGraph Image Generation API

## Overview
This API endpoint generates OpenGraph images for OK-OFFLINE with customizable text content. The images are 1200x630 PNG files with the OKNOTOK branding, suitable for social media sharing.

## Endpoint

### Generate OpenGraph Image

**POST** `/api/v1/opengraph/generate`

Generates a custom OpenGraph image with the provided text and returns the URL to the generated image.

#### Request

**Headers:**
```
Content-Type: application/json
```

**Body Parameters:**
```json
{
  "title": "string (optional, max 100 chars)",
  "subtitle": "string (optional, max 200 chars)",
  "year": "number (optional)"
}
```

- `title`: Main heading text. Defaults to "OK-OFFLINE" if not provided
- `subtitle`: Secondary text below the title. Optional
- `year`: Year to display. Defaults to current year if not provided

#### Response

**Success (200 OK):**
```json
{
  "success": true,
  "url": "http://100.104.170.10:3555/opengraph/og_[hash].png",
  "width": 1200,
  "height": 630,
  "cached": true/false
}
```

- `cached`: Indicates whether this image was returned from cache (true) or newly generated (false)

**Error (500 Internal Server Error):**
```json
{
  "error": "Failed to generate image: [error message]"
}
```

## Example Usage

### Basic Request
```bash
curl -X POST http://100.104.170.10:3555/api/v1/opengraph/generate \
  -H "Content-Type: application/json" \
  -d '{
    "title": "OK-OFFLINE",
    "subtitle": "Your offline companion for Black Rock City"
  }'
```

### JavaScript/Frontend Example
```javascript
async function generateOpenGraphImage(title, subtitle) {
  const response = await fetch('http://100.104.170.10:3555/api/v1/opengraph/generate', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      title: title || 'OK-OFFLINE',
      subtitle: subtitle,
      year: new Date().getFullYear()
    })
  });

  const data = await response.json();
  
  if (data.success) {
    return data.url; // Use this URL for og:image meta tag
  } else {
    console.error('Failed to generate OpenGraph image:', data.error);
  }
}
```

## Generated Image Details

The generated images include:
- **Size**: 1200x630 pixels (standard OpenGraph dimensions)
- **Format**: PNG
- **Background**: Black (#000000)
- **Font**: Berkeley Mono
- **Branding**: OKNOTOK circle logo on the right side
- **Footer**: "OKNOTOK | BRC [year]"

## Production Considerations

### CORS
The API currently allows CORS from the frontend domain. Ensure proper CORS configuration in production.

### Caching
Generated images are automatically cached based on the title, subtitle, and year parameters. The same combination of parameters will always return the same image URL without regenerating it. This ensures:

- Fast response times for repeated requests
- Consistent URLs for the same content
- Reduced server load

The cache key is generated using a normalized MD5 hash of the parameters, making URLs deterministic. Images are stored in `/public/opengraph/` and persist between requests. Consider implementing a cleanup strategy for old images in production.

### Rate Limiting
Currently no rate limiting is implemented. Consider adding rate limits in production to prevent abuse.

### URL Structure
Images are accessible at: `http://100.104.170.10:3555/opengraph/og_{hash}.png`

Note: The generated images are served directly from the Rails public directory, not through the `/api/v1` namespace.

## Test Endpoint

A test endpoint is available for browser preview:

**GET** `/api/v1/opengraph/test`

Query parameters:
- `title`: Test title
- `subtitle`: Test subtitle
- `year`: Test year

Example: `http://100.104.170.10:3555/api/v1/opengraph/test?title=Test&subtitle=Preview`

This renders the HTML template in the browser for visual testing.