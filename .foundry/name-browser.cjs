const {chromium} = require('/tmp/pwcheck/node_modules/playwright');
const assert = require('node:assert/strict');
(async () => {
  const browser = await chromium.launch({headless:true,executablePath:"/home/svetzal/.cache/puppeteer/chrome/linux-152.0.7977.54/chrome-linux64/chrome"});
  for (const theme of ['light','dark']) {
    const context = await browser.newContext({viewport:{width:375,height:812}});
    await context.addInitScript(t => localStorage.setItem('phx:theme',t), theme);
    const page = await context.newPage();
    await page.goto(process.argv[2]);
    await page.waitForFunction(t => document.documentElement.dataset.theme === t,theme);
    assert.equal(await page.title(), process.env.NAME_EXPECTED);
    assert.equal((await page.locator("header a[href='/']").first().textContent()).trim(), process.env.NAME_EXPECTED);
    assert.equal((await page.locator('#home h1').textContent()).trim(), process.env.NAME_EXPECTED);
    await page.keyboard.press('Tab');
    const focus = await page.evaluate(() => ({tag:document.activeElement.tagName, outline:getComputedStyle(document.activeElement).outlineStyle}));
    assert.equal(focus.tag, 'A');
    assert.notEqual(focus.outline, 'none');
    const form = page.locator('#lead-form');
    assert.equal(await form.locator('[name="_csrf_token"]').count(),1);
    await page.locator('#lead_name').focus();
    await page.keyboard.type('Browser enquiry '+theme);
    await page.keyboard.press('Tab');
    assert.equal(await page.locator('#lead_phone').evaluate(e=>e===document.activeElement),true);
    await page.keyboard.press('Enter');
    await page.waitForURL('**/leads');
    await page.waitForFunction(()=>document.activeElement.id==='lead_phone');
    assert.equal(await page.locator('#lead_phone').getAttribute('aria-invalid'),'true');
    assert.match(await page.locator('#lead_phone').getAttribute('aria-describedby'),/lead-contact-help.*lead_phone-errors/);
    assert.equal(await page.locator('#lead_name').inputValue(),'Browser enquiry '+theme);
    const contrast = await page.evaluate(() => {
      const rgb = color => {
        const canvas = document.createElement('canvas');
        canvas.width=canvas.height=1;
        const ctx = canvas.getContext('2d');
        ctx.fillStyle=color;ctx.fillRect(0,0,1,1);
        return [...ctx.getImageData(0,0,1,1).data];
      };
      const bg = rgb(getComputedStyle(document.body).backgroundColor);
      const base = bg[3] ? bg : rgb(getComputedStyle(document.documentElement).backgroundColor);
      const lum = c => c.slice(0,3).map(v=>v/255).map(v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4).reduce((s,v,i)=>s+v*[.2126,.7152,.0722][i],0);
      const ratio = color => {
        const c=rgb(color); const a=c[3]/255;
        const composite=c.slice(0,3).map((v,i)=>v*a+base[i]*(1-a));
        const l1=lum(composite),l2=lum(base);
        return (Math.max(l1,l2)+.05)/(Math.min(l1,l2)+.05);
      };
      return {
        labels: [...document.querySelectorAll('#lead-form .label')].map(e=>ratio(getComputedStyle(e).color)),
        error: ratio(getComputedStyle(document.querySelector('#lead_phone-errors p')).color),
        controls: [...document.querySelectorAll('#lead-form input:not([type=hidden]),#lead-form textarea')].map(e=>ratio(getComputedStyle(e).borderTopColor))
      };
    });
    assert.ok(contrast.labels.every(r=>r>=4.5), JSON.stringify(contrast));
    assert.ok(contrast.error>=4.5, JSON.stringify(contrast));
    assert.ok(contrast.controls.every(r=>r>=3), JSON.stringify(contrast));
    console.log(theme+': contrast '+JSON.stringify(contrast));
    await page.screenshot({path:'/tmp/starter-c9-name-'+theme+'-invalid.png',fullPage:true});
    assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
    await page.keyboard.type('555-0100');
    await page.keyboard.press('Enter');
    await page.waitForURL('**/?sent=1#lead-sent');
    assert.equal(await page.locator('#lead-sent[role="status"]').count(),1);
    console.log(theme+': keyboard submission, error focus, correction, saved status and mobile reflow passed');
    await context.close();
  }
  await browser.close();
})().catch(error=>{console.error(error);process.exit(1)});
