# Verifying an email on real clients

How the measurements behind the `html-email` skill were made, so the next project can repeat them.

## Rules

- **A browser is not a mail client.** A browser page that added `data-ogsb` attributes and fake inline colours "showed" a fix that did nothing on the phone. Use a browser only to check that the HTML renders and the selectors are valid.
- **Ask first.** Test emails go out through the project's mail settings. Ask the owner, then send only to the addresses the project already notifies, or to addresses the owner gives. Change no code or settings of the running app to do it.
- **Test the HTML that is actually sent,** after any template engine or CSS inliner, not the template.

## Steps

1. **Labelled variants in one email.** Put several numbered samples in one email, each a small copy of the real design: "1. Today", "2. Rule on the element", "3. Rule on an inner element", "4. Dark by design", "5. Dates: a / b / c". One screenshot then answers several questions.
2. **A calibration email.** A column of labelled swatches, `B1 #FFFFFF` down to `B13 #000000`, neutral and tinted, plus text samples `T1 ...`. Each row is a label cell, a hex cell, and a cell with that background. It shows how the client maps every colour.
3. **Send through the app's own mail code.** Build the HTML, then call the project's send function from a short script run where the app runs (for example `docker exec -i <app-container> python - < script.py`). Keep scratch scripts outside the repository.
4. **Get a direct screenshot.** A screenshot forwarded through a chat app may arrive heavily compressed. One came through WhatsApp 180px wide and was useless. Ask for the file itself, or a "document" attachment, and for a PNG when possible.
5. **Read pixels, do not guess.** On Windows:

   ```powershell
   Add-Type -AssemblyName System.Drawing
   $img = [System.Drawing.Bitmap]::new("T:\task\shot.png")
   "size $($img.Width)x$($img.Height)"
   for ($y = 300; $y -lt $img.Height; $y += 25) {
     $c = $img.GetPixel(120, $y); "{0,5} #{1:X2}{2:X2}{3:X2}" -f $y, $c.R, $c.G, $c.B
   }
   $img.Dispose()
   ```

   Scan a column to find the swatches, then sample each one. Record the client name, app version and OS version with the values.
6. **A final send from the real code.** Render the email with the branch's actual layout code, not injected CSS, send it, and get the owner's look before the pull request.
7. **Tests.** Pin the exact CSS rules and the chart output (heights, zero data, highlight, escaping, axis labels across a clock change, data against a real database, the email still sent when the chart data fails). Show that each new test fails on the old code.

## Layout screenshots in a browser

Headless Edge gives quick light and dark screenshots of the layout. It checks layout only, never client behaviour:

```powershell
$edge = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
& $edge --headless=new --disable-gpu --hide-scrollbars --user-data-dir="T:\task\edge-profile" `
  --window-size=430,1600 --blink-settings=preferredColorScheme=1 `
  --screenshot="T:\task\light.png" "file:///T:/task/email.html"
# dark: --force-dark-mode --blink-settings=preferredColorScheme=0
```

Headless Edge lays the page out at about 500px wide at least, so a narrower window crops on the right. To check phone widths, place the email in fixed-width iframes (320px, 430px) on one page and screenshot that page.
