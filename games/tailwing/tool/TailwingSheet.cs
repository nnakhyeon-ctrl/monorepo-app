// Review contact sheet, not a production game asset or a screenshot.
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Collections.Generic;
using System.Web.Script.Serialization;
public static class TailwingSheet {
  static void Fit(Graphics g,Image i,RectangleF r){float s=Math.Min(r.Width/i.Width,r.Height/i.Height);g.DrawImage(i,r.X+(r.Width-i.Width*s)/2,r.Y+(r.Height-i.Height*s)/2,i.Width*s,i.Height*s);}
  public static int Main(string[] args){
    if(args.Length!=1)return 2;var root=Path.GetFullPath(args[0]);
    var species=new[]{"rabbit","fox","bear","turtle","otter","owl","squirrel","hedgehog","penguin","frog","eagle","volt"};
    var report=new List<object>();
    using(var sheet=new Bitmap(1536,1740,PixelFormat.Format24bppRgb))using(var g=Graphics.FromImage(sheet))using(var font=new Font("Arial",18,FontStyle.Bold)){
      g.Clear(Color.FromArgb(10,25,40));g.InterpolationMode=InterpolationMode.HighQualityBicubic;
      g.DrawString("TAILWING | authored art review - not gameplay capture",font,Brushes.White,20,12);
      for(int n=0;n<species.Length;n++){
        int x=n%3*512,y=55+n/3*325;g.DrawString(species[n],font,Brushes.Aquamarine,x+18,y);
        foreach(var kind in new[]{"portrait","ship"}){
          var path=Path.Combine(root,"assets","tailwing",species[n]+"_"+kind+".png");
          using(var img=new Bitmap(path)){
            int left=kind=="portrait"?x+8:x+226,width=kind=="portrait"?210:278;
            Fit(g,img,new RectangleF(left,y+28,width,285));
            report.Add(new{species=species[n],kind=kind,width=img.Width,height=img.Height,
              transparentCorners=img.GetPixel(0,0).A==0&&img.GetPixel(img.Width-1,0).A==0&&img.GetPixel(0,img.Height-1).A==0&&img.GetPixel(img.Width-1,img.Height-1).A==0});
          }
        }
      }
      using(var bg=Image.FromFile(Path.Combine(root,"assets/tailwing/world_background.png")))Fit(g,bg,new RectangleF(0,1370,720,350));
      using(var enemy=Image.FromFile(Path.Combine(root,"assets/tailwing/world_enemies.png")))Fit(g,enemy,new RectangleF(760,1370,720,350));
      var folder=Path.Combine(root,"docs","tailwing");Directory.CreateDirectory(folder);
      sheet.Save(Path.Combine(folder,"ROSTER-CONTACT-SHEET.png"),ImageFormat.Png);
      File.WriteAllText(Path.Combine(folder,"ASSET-FORMAT-CHECKS.json"),new JavaScriptSerializer().Serialize(report));
    }
    Console.WriteLine("Art review sheet and corner-alpha checks saved; not runtime certification.");return 0;
  }
}
