# Full ICU Customization for Node.js DHI

## Overview

This customization adds **full ICU (International Components for Unicode)** support to Node.js Docker Hardened Images. By default, Node.js ships with "small-ICU" which includes limited locale data for basic internationalization. Full ICU provides comprehensive support for all locales, timezones, currencies, and formatting options.

## Why Full ICU?

### Default Node.js ICU (small-icu)

- Contains data for **English locale only**
- Limited timezone support
- Basic number and date formatting
- Smaller binary size (~30MB saved)
- Sufficient for English-only applications

### Full ICU Benefits

- **All locales**: Support for 600+ locales worldwide
- **Complete timezone data**: All IANA timezones
- **Currency formatting**: All currencies with proper symbols
- **Date/time formatting**: Locale-specific formats
- **Collation**: Proper string sorting for all languages
- **Number formatting**: Locale-aware number display

## When to Use Full ICU

✅ **Good use cases:**
- Multi-language applications serving global users
- Financial applications requiring currency formatting
- Applications with locale-specific date/time display
- International e-commerce platforms
- SaaS products with global customers

❌ **Not needed when:**
- English-only application
- No internationalization requirements
- Server-side rendering not used for localized content
- API only returns raw data (client handles formatting)

## Implementation in DHI

### Dockerfile Changes

The customization is applied in both DHI Node.js Dockerfiles:

**Development** (`docker/node/Dockerfile.dhi.dev`):
```dockerfile
FROM <ORG>/dhi-node:latest

# Install Full ICU data package
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    icu-data-full && \
    rm -rf /var/lib/apt/lists/*

# Point Node.js to the full ICU data
ENV NODE_ICU_DATA=/usr/share/icu
```

**Production** (`docker/node/Dockerfile.dhi.prod`):
```dockerfile
# Both builder and runtime stages need Full ICU
FROM <ORG>/dhi-node:latest AS builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    icu-data-full && \
    rm -rf /var/lib/apt/lists/*

ENV NODE_ICU_DATA=/usr/share/icu

# ... build steps ...

FROM <ORG>/dhi-node:latest

# Install again in runtime stage
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    icu-data-full && \
    rm -rf /var/lib/apt/lists/*

ENV NODE_ICU_DATA=/usr/share/icu
```

### Package Details

- **Package**: `icu-data-full`
- **Source**: Debian Bookworm repositories
- **Size**: ~11MB (varies by version)
- **Maintenance**: Updated with Debian security patches

## Testing Full ICU

### Quick Test

```bash
# Start the DHI environment
docker compose -f compose.dhi.yaml up

# Test various locales
curl 'http://localhost:8080/api/time?locale=ja-JP&tz=Asia/Tokyo'
curl 'http://localhost:8080/api/time?locale=ar-SA&tz=Asia/Riyadh'
curl 'http://localhost:8080/api/time?locale=hi-IN&tz=Asia/Kolkata'
```

### Verify ICU Data Path

```bash
# Check environment variable inside container
docker compose -f compose.dhi.yaml exec app printenv NODE_ICU_DATA

# Should output: /usr/share/icu
```

### Node.js Code Example

```javascript
// Date formatting with Full ICU
const date = new Date();

// Japanese locale with Tokyo timezone
const ja = new Intl.DateTimeFormat('ja-JP', {
  dateStyle: 'full',
  timeStyle: 'long',
  timeZone: 'Asia/Tokyo'
}).format(date);

console.log(ja);
// Output: 2024年1月15日月曜日 14:30:45 日本標準時

// Arabic locale with Saudi Arabia timezone
const ar = new Intl.DateTimeFormat('ar-SA', {
  dateStyle: 'full',
  timeStyle: 'long',
  timeZone: 'Asia/Riyadh'
}).format(date);

console.log(ar);
// Output: الاثنين، 15 يناير 2024 م 8:30:45 ص توقيت العربية السعودية

// Currency formatting
const price = 1234.56;

const usd = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD'
}).format(price);

const jpy = new Intl.NumberFormat('ja-JP', {
  style: 'currency',
  currency: 'JPY'
}).format(price);

console.log(usd); // $1,234.56
console.log(jpy); // ¥1,235
```

## Comparison: DOI vs DHI with Full ICU

| Aspect | DOI (default) | DHI + Full ICU |
|--------|---------------|----------------|
| ICU Data | small-icu (English only) | Full ICU (all locales) |
| Locales Supported | ~1 | 600+ |
| Image Size | ~950MB | ~961MB (+11MB) |
| Timezone Data | Limited | Complete IANA |
| CVE Count | Higher | Lower (DHI benefit) |
| Attack Surface | Standard | Reduced (DHI benefit) |

## Security Considerations

### Benefits
- **DHI Foundation**: Built on hardened base with fewer CVEs
- **Official Packages**: ICU data from Debian official repos
- **No Third-party**: No npm packages or external sources
- **Predictable Updates**: Follows Debian security schedule

### Trade-offs
- **Slightly larger image**: +11MB for ICU data
- **Additional package**: One more component to maintain
- **Increased complexity**: Extra layer in Dockerfile

### Best Practices
1. **Only add if needed**: Don't include Full ICU "just in case"
2. **Document why**: Explain the business need in comments
3. **Test thoroughly**: Verify all required locales work
4. **Monitor CVEs**: Keep DHI base image updated
5. **Consider alternatives**: Can client-side handle formatting?

## Alternative Approaches

### 1. Client-Side Formatting
Let the browser handle internationalization:
```javascript
// Server returns raw data
res.json({ timestamp: Date.now() });

// Client formats with browser's ICU
const formatter = new Intl.DateTimeFormat('ja-JP', { ... });
```

**Pros**: No server-side ICU needed, reduces server load
**Cons**: More client code, inconsistent formatting across clients

### 2. Separate Formatting Service
Dedicated microservice for i18n:
```
┌─────────┐     ┌─────────┐     ┌──────────┐
│ Client  │────▶│ API     │────▶│ i18n     │
│         │◀────│ (no ICU)│◀────│ (Full ICU)│
└─────────┘     └─────────┘     └──────────┘
```

**Pros**: Isolates complexity, scalable
**Cons**: Added latency, more infrastructure

### 3. npm Package (icu-data)
```bash
npm install full-icu
```

**Pros**: No Dockerfile changes
**Cons**: Larger node_modules, npm dependency, less secure

## Troubleshooting

### ICU Data Not Found

**Symptom**: `RangeError: Incorrect locale information provided`

**Solution**:
```bash
# Verify ICU data path
docker exec -it <container> ls -la /usr/share/icu

# Check environment variable
docker exec -it <container> printenv NODE_ICU_DATA
```

### Wrong Locale Output

**Symptom**: Falls back to English formatting

**Solution**:
```javascript
// Test if locale is supported
try {
  const formatter = new Intl.DateTimeFormat('your-locale');
  console.log('Locale supported:', formatter.resolvedOptions().locale);
} catch (err) {
  console.error('Locale not supported:', err);
}
```

### Image Size Concerns

**Solution**:
- Full ICU adds ~11MB (minimal impact on modern infrastructure)
- DHI already optimizes base image size
- Multi-stage builds keep final image lean
- Compress with `docker image save | gzip` for transport

## Workshop Demo Points

1. **Show the need**: Try Japanese locale with DOI → fails or wrong output
2. **Add customization**: Apply Full ICU to DHI Dockerfile
3. **Rebuild and test**: Japanese, Arabic, Hindi formatting works
4. **Compare sizes**: Minimal size increase for major functionality
5. **Scan both**: DHI still has fewer CVEs despite customization

## Production Checklist

- [ ] Document business requirement for Full ICU
- [ ] Test all required locales in staging
- [ ] Verify performance impact (minimal)
- [ ] Update build scripts and documentation for DHI + Full ICU
- [ ] Pin DHI base image by digest (not `:latest`)
- [ ] Monitor CVE reports for ICU package
- [ ] Include Full ICU in security audit documentation
- [ ] Train team on when/why this customization exists

## Additional Resources

- [Node.js Internationalization](https://nodejs.org/api/intl.html)
- [ICU Documentation](https://unicode-org.github.io/icu/)
- [Debian ICU Packages](https://packages.debian.org/search?keywords=icu)
- [Docker Hardened Images Docs](https://docs.docker.com/hardened-images/)
- [MDN Intl Documentation](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl)

## Questions?

- Check WORKSHOP.md for hands-on exercises
- Review app/src/server.ts for code examples
- Test with app/public/index.html interactive demo
- Scan images with scripts/scan-image.sh to verify security posture
