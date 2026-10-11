import { HTML_MAX_BYTES, sanitizeHtmlCard } from './html-card.js';

describe('sanitizeHtmlCard', () => {
  const clean = (html: string) => sanitizeHtmlCard({ html })?.html ?? '';

  it('wraps a fragment in a page that forbids all network access', () => {
    const card = sanitizeHtmlCard({ title: 'Timeline', html: '<div class="t">Hi</div>', height: 9999 });
    expect(card?.title).toBe('Timeline');
    expect(card?.height).toBe(640);
    expect(card?.html).toContain("default-src 'none'");
    expect(card?.html).toContain("connect-src 'none'");
    expect(card?.html).toContain('<div class="t">Hi</div>');
  });

  it('keeps inline scripts and handlers, which is what makes it interactive', () => {
    const html = clean('<button onclick="flip()">Flip</button><script>function flip(){}</script>');
    expect(html).toContain('onclick="flip()"');
    expect(html).toContain('function flip(){}');
  });

  it.each([
    ['an external script', '<script src="https://evil.example/x.js"></script>', 'evil.example'],
    ['an iframe', '<iframe src="https://evil.example"></iframe>', 'iframe'],
    ['a form', '<form action="https://evil.example"><input></form>', 'evil.example'],
    ['a link', '<a href="https://evil.example">x</a>', 'evil.example'],
    ['a remote image', '<img src="https://evil.example/p.png">', 'evil.example'],
    ['a stylesheet', '<link rel="stylesheet" href="https://evil.example/s.css">', 'evil.example'],
    ['a css fetch', '<div style="background:url(https://evil.example/t)"></div>', 'evil.example'],
    ['a meta refresh', '<meta http-equiv="refresh" content="0;url=https://evil.example">', 'evil.example'],
  ])('strips %s', (_, input, banned) => {
    const html = clean(`<p>ok</p>${input}`);
    expect(html.replace(/Content-Security-Policy" content="[^"]*"/, '')).not.toContain(banned);
    expect(html).toContain('<p>ok</p>');
  });

  it('allows inline data images', () => {
    expect(clean('<img src="data:image/png;base64,AAAA">')).toContain('data:image/png;base64,AAAA');
  });

  it('refuses oversized or empty pages', () => {
    expect(sanitizeHtmlCard({ html: `<p>${'x'.repeat(HTML_MAX_BYTES)}</p>` })).toBeNull();
    expect(sanitizeHtmlCard({ html: 'just text' })).toBeNull();
    expect(sanitizeHtmlCard({ html: 42 })).toBeNull();
  });
});
