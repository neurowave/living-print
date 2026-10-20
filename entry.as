import { KeyboardEvent, TextInput } from "rive/events";
import { PropertyString } from "rive/data";
import { Path } from "rive/path";
import { Paint } from "rive/paint";
import { Color } from "rive/color";
import { Renderer } from "rive/renderer";
import { NodeData } from "rive/artboard";
import { clamp, xy } from "./support";

const chars="ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-";
const advances:f64[]=[10.1692,9.7059,10.6961,10.5818,9.014,8.8743,10.8992,10.8611,4.6912,8.6204,9.9344,8.5506,12.9432,10.9944,11.1404,9.5027,11.1404,9.5662,9.5408,9.5916,10.8738,10.1692,14.0096,10.0677,10.0232,9.3758,9.4012,6.4876,9.1282,9.2298,9.5979,8.9124,9.2615,8.5569,9.2425,9.2615,7.1795];
function width(s:string,n:i32):f64 {
    let x:f64=0;for(let i=0;i<n;i++){let j=chars.indexOf(s.charAt(i));x+=((j<0?9:advances[j])-1.2)*24/13+2;}return x;
}
export class Entry {
    property:PropertyString?;localValue:string="";active:bool=false;caret:i32=0;anchor:i32=0;blink:f64=0;saved:string="";
    path:Path=new Path();paint:Paint=new Paint();
    constructor(property:PropertyString?,initial:string=""){this.property=property;this.localValue=initial;}
    get value():string {let p=this.property;return p!=null?p.value:this.localValue;}
    set value(v:string){let p=this.property;if(p!=null)p.value=v;else this.localValue=v;}
    replace(s:string):void {
        let old=this.value,a=<i32>Math.min(this.caret,this.anchor),b=<i32>Math.max(this.caret,this.anchor);
        let filtered="",upper=s.toUpperCase();
        for(let i=0;i<upper.length;i++)if(chars.indexOf(upper.charAt(i))>=0)filtered+=upper.charAt(i);
        filtered=filtered.substring(0,12-(old.length-(b-a)));
        this.value=old.substring(0,a)+filtered+old.substring(b);
        this.caret=a+filtered.length;this.anchor=this.caret;this.blink=0;
    }
    click(x:f64):void {
        let s=this.value;
        if(!this.active){this.active=true;this.saved=s;this.anchor=0;this.caret=s.length;}
        else{let nearest=0,best:f64=Infinity;for(let i=0;i<=s.length;i++){let d=Math.abs(x-18-width(s,i));if(d<best){nearest=i;best=d;}}this.caret=nearest;this.anchor=nearest;}
        this.blink=0;
    }
    key(event:KeyboardEvent):bool {return this.keyInput(event.key,event.phase,event.shift,event.meta,event.control);}
    keyInput(k:f64,phase:string,shift:bool=false,meta:bool=false,control:bool=false):bool {
        if(!this.active || phase=="up")return false;
        let s=this.value;this.blink=0;
        if((meta || control) && k==65){this.anchor=0;this.caret=s.length;}
        else if(k==257 || k==258)this.active=false;
        else if(k==256){this.value=this.saved;this.active=false;}
        else if(k==259){if(this.caret==this.anchor)this.anchor=<i32>Math.max(0,this.caret-1);this.replace("");}
        else if(k==261){if(this.caret==this.anchor)this.anchor=<i32>Math.min(s.length,this.caret+1);this.replace("");}
        else if(k==263 || k==262 || k==268 || k==269){
            let next=this.caret;
            if(k==268 || (k==263 && (meta || control)))next=0;
            else if(k==269 || (k==262 && (meta || control)))next=s.length;
            else if(!shift && this.caret!=this.anchor)next=k==263?<i32>Math.min(this.caret,this.anchor):<i32>Math.max(this.caret,this.anchor);
            else next=<i32>clamp(this.caret+(k==263?-1:1),0,s.length);
            this.caret=next;if(!shift)this.anchor=next;
        }
        return true;
    }
    text(event:TextInput):bool {return this.insert(event.text);}
    insert(text:string):bool {
        if(!this.active)return false;
        let filtered="",upper=text.toUpperCase();
        for(let i=0;i<upper.length;i++)if(chars.indexOf(upper.charAt(i))>=0)filtered+=upper.charAt(i);
        if(filtered.length>0)this.replace(filtered);return true;
    }
    rect(r:Renderer,x:f64,y:f64,w:f64,h:f64,color:Color):void {
        let p=this.path;p.reset();p.moveTo(xy(x,y));p.lineTo(xy(x+w,y));p.lineTo(xy(x+w,y+h));p.lineTo(xy(x,y+h));p.close();this.paint.color=color;r.drawPath(p,this.paint);
    }
    draw(r:Renderer,field:NodeData?,w:f64):void {
        if(!this.active || field==null)return;
        let s=this.value,a=<i32>Math.min(this.caret,this.anchor),b=<i32>Math.max(this.caret,this.anchor);
        r.save();r.transform(field.worldTransform());
        this.rect(r,0,42,w,1,Color.rgb(55,20,114));
        if(a!=b)this.rect(r,18+width(s,a),8,width(s,b)-width(s,a),26,Color.rgba(255,101,62,70));
        else if(this.blink%1<.6)this.rect(r,18+width(s,this.caret),10,1,24,Color.rgb(55,20,114));
        r.restore();
    }
}
