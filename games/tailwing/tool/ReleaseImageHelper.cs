// Deterministic local asset format/size conversion. No generated gameplay.
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Web.Script.Serialization;

public class ImageJob {
    public string source { get; set; }
    public string target { get; set; }
    public int width { get; set; }
    public int height { get; set; }
    public bool alpha { get; set; }
}
public class ImagePlan {
    public string root { get; set; }
    public List<ImageJob> jobs { get; set; }
}
public static class ReleaseImageHelper {
    public static int Main(string[] args) {
        if (args.Length != 1) return 2;
        var plan = new JavaScriptSerializer().Deserialize<ImagePlan>(File.ReadAllText(args[0]));
        var root = Path.GetFullPath(plan.root).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        foreach (var job in plan.jobs) {
            var source = Path.GetFullPath(job.source);
            var target = Path.GetFullPath(job.target);
            if (!source.StartsWith(root, StringComparison.OrdinalIgnoreCase) ||
                !target.StartsWith(root, StringComparison.OrdinalIgnoreCase) || source == target ||
                job.width < 16 || job.height < 16 || job.width > 2048 || job.height > 2048) return 3;
            Directory.CreateDirectory(Path.GetDirectoryName(target));
            using (var input = Image.FromFile(source)) {
                if (input.Width > 8192 || input.Height > 8192) return 4;
                var format = job.alpha ? PixelFormat.Format32bppArgb : PixelFormat.Format24bppRgb;
                using (var bitmap = new Bitmap(job.width, job.height, format))
                using (var canvas = Graphics.FromImage(bitmap)) {
                    canvas.Clear(job.alpha ? Color.Transparent : Color.FromArgb(255, 8, 22, 33));
                    if (input.Width == job.width && input.Height == job.height) {
                        canvas.DrawImageUnscaled(input, 0, 0);
                    } else {
                        canvas.CompositingQuality = CompositingQuality.HighQuality;
                        canvas.InterpolationMode = InterpolationMode.HighQualityBicubic;
                        canvas.PixelOffsetMode = PixelOffsetMode.HighQuality;
                        using (var attributes = new ImageAttributes()) {
                            attributes.SetWrapMode(WrapMode.TileFlipXY);
                            canvas.DrawImage(input, new Rectangle(0, 0, job.width, job.height),
                                0, 0, input.Width, input.Height, GraphicsUnit.Pixel, attributes);
                        }
                    }
                    bitmap.Save(target, ImageFormat.Png);
                }
            }
        }
        Console.WriteLine("Local image format/size conversion complete. Not submitted.");
        return 0;
    }
}
