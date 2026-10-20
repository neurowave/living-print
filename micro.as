import { Artboard, Animation } from "rive/artboard";
import { Vector } from "rive/vector";
import { Hit, clamp } from "./support";

const names:string[]=["Waves","Checker","Orbit","Fragments"];
const tabs:string[]=["Patterns","Type","Color"];
class Track {
    anim:Animation;value:f64;from:f64;target:f64;time:f64=1;
    constructor(anim:Animation,target:f64){this.anim=anim;this.value=target;this.from=target;this.target=target;}
}
export function ease(t:f64):f64 {
    let q=t;
    for(let i=0;i<6;i++){let r=1-q,x=3*r*r*q*.23+3*r*q*q*.32+q*q*q,d=3*r*r*.23+6*r*q*(.32-.23)+3*q*q*(1-.32);q=clamp(q-(x-t)/Math.max(.0001,d),0,1);}
    return 1-(1-q)*(1-q)*(1-q);
}
export function nodePoint(art:Artboard,name:string,q:Vector):Hit? {
    let n=art.node(name);if(n==null)return null;
    let m=n.worldTransform();n.release();
    return new Hit(m.invert().transformPoint(q));
}
export class Micro {
    art:Artboard;tracks:Map<string,Track>=new Map<string,Track>();
    constructor(art:Artboard){this.art=art;}
    pose(name:string,target:f64,dt:f64,instant:bool):void {
        if(!this.tracks.has(name))this.tracks.set(name,new Track(this.art.animation(name)!,target));
        let c=this.tracks.get(name);
        if(target!=c.target){c.from=c.value;c.target=target;c.time=0;}
        if(instant){c.value=target;c.from=target;c.time=1;}
        else {c.time=Math.min(1,c.time+dt/Math.max(.01,c.anim.duration));c.value=c.from+(c.target-c.from)*ease(c.time);}
        c.anim.setTimePercentage(c.value);
    }
    inside(name:string,q:Vector,w:f64,h:f64,pad:f64=0):bool {
        let p=nodePoint(this.art,name,q);
        return p!=null && p.x>=-pad && p.x<=w+pad && p.y>=-pad && p.y<=h+pad;
    }
    pick(q:Hit?,w:f64,pad:f64,listHeight:f64,trackWidth:f64):string {
        if(q==null)return "";
        let pos=q.position,content=w-2*pad;
        if(this.inside("Pattern viewport",pos,content-15,listHeight))for(let i=0;i<names.length;i++)if(this.inside("Choose "+names[i],pos,content-15,82))return names[i];
        for(let i=0;i<tabs.length;i++)if(this.inside(tabs[i],pos,(content-18)/3,44))return tabs[i];
        for(let i=1;i<=6;i++)if(this.inside("Palette "+i.toString(),pos,56,56))return "Palette "+i.toString();
        if(this.inside("Play pause",pos,54,54))return "Transport";
        for(let i=0;i<2;i++){let name=i==0?"Scale":"Motion";if(this.inside(name+" vector slider",pos,trackWidth,32,12))return "Handle "+name;}
        if(this.inside("Mark field",pos,content,43))return "Mark";
        if(this.inside("Lift the paper",pos,content,24,6))return "Lift";
        return "";
    }
    update(dt:f64,pattern:i32,palette:i32,tab:i32,paused:bool,focus:bool,hover:string,press:string,reduced:bool):void {
        if(reduced){hover="";press="";}
        for(let i=0;i<names.length;i++){let n=names[i];this.pose("Select "+n,pattern==i?1:0,dt,reduced);this.pose("Hover "+n,hover==n?1:0,dt,reduced);}
        for(let i=0;i<tabs.length;i++){let n=tabs[i];this.pose("Tab "+n,tab==i?1:0,dt,reduced);this.pose("Hover "+n,hover==n?1:0,dt,reduced);this.pose("Press "+n,press==n?1:0,dt,reduced);}
        for(let i=1;i<=6;i++){let n="Palette "+i.toString();this.pose(n,palette==i-1?1:0,dt,reduced);this.pose("Hover "+n,hover==n?1:0,dt,reduced);this.pose("Press "+n,press==n?1:0,dt,reduced);}
        this.pose("Transport state",paused?1:0,dt,reduced);this.pose("Hover Transport",hover=="Transport"?1:0,dt,reduced);this.pose("Press Transport",press=="Transport"?1:0,dt,reduced);
        for(let i=0;i<2;i++){let n=i==0?"Handle Scale":"Handle Motion";this.pose(n,hover==n || press==n?1:0,dt,reduced);}
        this.pose("Focus mark",focus?1:0,dt,reduced);this.pose("Hover Lift",hover=="Lift" || press=="Lift"?1:0,dt,reduced);
        this.art.advance(0);
    }
}
