import { Layout, Context } from "rive/host";
import { Artboard } from "rive/artboard";
import { Canvas } from "rive/canvas";
import { Mat4 } from "rive/mat4";
import { Mat2D } from "rive/mat2d";
import { Vector } from "rive/vector";
import { Color } from "rive/color";
import { Renderer } from "rive/renderer";
import { BlendMode } from "rive/paint";
import { ImageSampler } from "rive/image";
import { PointerEvent, KeyboardEvent, TextInput } from "rive/events";
import { GPUCanvas, GPUBuffer, GPUPipeline, GPUBindGroup, GPUBindGroupUBO, GPUTexture, GPUTextureView, GPUColorAttachment, GPUPassDesc } from "rive/gpu";
import { BufferUsage, TextureFormat, StoreOp } from "rive/gpu_enums";
import { Stage, Sheet } from "./stage";
import { Shoe } from "./shoe";
import { Entry } from "./entry";
import { Micro, nodePoint } from "./micro";
import { view, point, hit } from "./surfaces";
import { texture, makePipeline } from "./gpu_helpers";
import { Config, Hit, clamp, xy, translate, scale, floats } from "./support";

const palettes:i32[][]=[[55,20,114,255,91,53,250,186,203],[55,20,114,255,102,60,248,196,214],[55,20,114,194,249,42,255,251,219],[99,22,98,255,124,160,255,216,224],[36,22,65,245,205,52,253,250,237],[248,240,223,255,100,69,40,35,51]];
const patternNames:string[]=["Waves","Checker","Orbit","Fragments"];
const reflowNames:string[]=["sheetGap","sheetPadTop","sheetPadBottom","sheetPadSide","headingHeight","headlineSize","headlineTracking","listHeight","controlsHeight","identityHeight","headerCaptionOpacity","trackWidth"];
const desktop:f64[]=[14,42,26,50,138,84,-2,315,128,78,1,242];
const phone:f64[]=[11,28,20,32,82,47,-1,234,104,78,0,130];

export class Main extends Layout {
    @input ui:Artboard?=null;
    @input header:Artboard?=null;
    @input mark:Artboard?=null;
    @input manifesto:Artboard?=null;
    @input waves:Artboard?=null;
    @input checker:Artboard?=null;
    @input orbit:Artboard?=null;
    @input stripes:Artboard?=null;

    context:Context?=null;vm:Config?=null;ready:bool=false;dirty:bool=true;layoutDirty:bool=true;
    gpu:GPUCanvas?=null;patternCanvas:Canvas?=null;markCanvas:Canvas?=null;letterCanvas:Canvas?=null;
    patterns:Artboard[]=[];markArt:Artboard?=null;headerArt:Artboard?=null;letterArt:Artboard?=null;
    stage:Stage?=null;sheet:Sheet?=null;back:Sheet?=null;front:Sheet?=null;bridge:Sheet?=null;
    shoe:Shoe?=null;entry:Entry?=null;micro:Micro?=null;
    studioPipeline:GPUPipeline?=null;studioUbo:GPUBuffer?=null;studioBg:GPUBindGroup?=null;
    studioBuf:ArrayBuffer=new ArrayBuffer(32);
    depth:GPUTexture?=null;depthView:GPUTextureView?=null;msaa:GPUTexture?=null;msaaView:GPUTextureView?=null;resolveView:GPUTextureView?=null;
    w:f64=1600;h:f64=900;dpr:f64=1;renderScale:f64=1;compact:bool=false;letterReady:bool=false;
    t:f64=0;flat:f64=0;pull:f64=0;yaw:f64=0;pitch:f64=0;hoverX:f64=0;hoverY:f64=0;tiltX:f64=0;tiltY:f64=0;
    pattern:i32=0;palette:i32=0;patternScale:f64=1.2;speed:f64=.6;scrollVelocity:f64=0;scrollFlex:f64=0;reveal:f64=0;
    eye:Vector=Vector();vp:Mat4=Mat4.identity();model:Mat4=Mat4.identity();
    hoverPos:Hit?=null;pressPoint:Vector=Vector();last:Vector=Vector();microPress:string="";slider:string="";
    capture:bool=false;flexing:bool=false;dragging:bool=false;moved:bool=false;pullStart:f64=0;

    override init(context:Context):bool {
        this.context=context;let vm=context.viewModel();if(vm==null || this.ready)return true;
        this.vm=new Config(vm);this.gpu=context.gpuCanvas(1600,900)!;
        this.patternCanvas=context.canvas(1536,1536)!;this.markCanvas=context.canvas(1024,256)!;this.letterCanvas=context.canvas(1024,96)!;
        let sources:Artboard[]=[this.waves!,this.checker!,this.orbit!,this.stripes!];
        for(let i=0;i<sources.length;i++){let a=sources[i].instance(vm);a.advance(0);this.patterns.push(a);}
        this.markArt=this.mark!.instance(vm);this.headerArt=this.header!.instance(vm);this.letterArt=this.manifesto!.instance(vm);
        let stage=new Stage(context,this.patternCanvas!,this.letterCanvas!);this.stage=stage;
        let art=this.ui!.instance(vm);art.advance(0);
        this.sheet=stage.sheet(art,context.canvas(1240,1960)!,620,980,0);
        this.back=stage.sheet(null,this.patternCanvas!,620,980,1);this.front=stage.sheet(null,this.patternCanvas!,620,980,2);this.bridge=stage.sheet(null,this.patternCanvas!,620,880,3);
        this.shoe=new Shoe(context,this.patternCanvas!,this.markCanvas!,stage);this.entry=new Entry(this.vm!.s("mark"));this.micro=new Micro(art);
        this.studioPipeline=makePipeline(context.shader("studio")!,false,false,[],<TextureFormat>this.gpu!.format,true);
        this.studioUbo=new GPUBuffer(BufferUsage.uniform,32);
        this.studioBg=new GPUBindGroup(this.studioPipeline!.getBindGroupLayout(0),[new GPUBindGroupUBO(0,this.studioUbo!)]);
        this.ready=true;return true;
    }
    override resize(w:f64,h:f64,dpr:f64):void {this.w=Math.max(1,w);this.h=Math.max(1,h);this.dpr=Math.max(1,dpr);this.dirty=true;this.layoutDirty=true;}
    sync():void {
        let vm=this.vm!,action=vm.n("action").value;
        if(action>0){
            if(action<=4){vm.n("pattern").value=action-1;this.reveal=.001;}
            else if(action>=10 && action<=15){vm.n("palette").value=action-10;this.reveal=.001;}
            else if(action==20)vm.b("paused").value=!vm.b("paused").value;
            else if(action==21)vm.b("flat").value=!vm.b("flat").value;
            else if(action==22){vm.n("orbitYaw").value=0;vm.n("orbitPitch").value=0;}
            else if(action==40){vm.n("scrollY").value=0;vm.n("tab").value=0;}
            else if(action==41){this.entry!.click(18);vm.n("tab").value=1;}
            else if(action==42){vm.n("palette").value=(vm.n("palette").value+1)%6;vm.n("tab").value=2;this.reveal=.001;}
            vm.n("action").value=0;
        }
        this.pattern=<i32>clamp(Math.floor(vm.n("pattern").value),0,3);this.palette=<i32>clamp(Math.floor(vm.n("palette").value),0,5);
        let p=palettes[this.palette],inks=["ink","accent","paper"];
        for(let i=0;i<3;i++)vm.c(inks[i]).value=Color.rgb(p[i*3],p[i*3+1],p[i*3+2]);
        for(let i=0;i<4;i++){vm.c("row"+i.toString()).value=i==this.pattern?Color.rgb(255,101,62):Color.rgb(243,240,230);vm.n("check"+i.toString()).value=i==this.pattern?1:0;}
        for(let i=0;i<6;i++)vm.c("palette"+i.toString()).value=i==this.palette?Color.rgb(55,20,114):Color.rgba(55,20,114,0);
        for(let i=0;i<3;i++){let active=i==vm.n("tab").value;vm.c("tab"+i.toString()).value=active?Color.rgb(255,101,62):Color.rgb(240,235,231);vm.c("tabText"+i.toString()).value=active?Color.rgb(255,254,241):Color.rgb(55,20,114);}
        this.patternScale=clamp(vm.n("scale").value,.5,3);this.speed=clamp(vm.n("speed").value,0,2);
        let tw=vm.n("trackWidth").value;vm.n("scaleThumb").value=(this.patternScale-.5)/2.5*tw;vm.n("speedThumb").value=this.speed/2*tw;
        vm.s("scaleLabel").value=(<i32>Math.floor(this.patternScale*100+.5)).toString()+"%";vm.s("speedLabel").value=(<i32>Math.floor(this.speed*100+.5)).toString()+"%";
        let highlights:Color[]=[Color.rgb(195,253,48),Color.rgb(240,183,75),Color.rgb(225,245,135),Color.rgb(235,172,245),Color.rgb(255,218,59),Color.rgb(190,245,65)];vm.c("highlight").value=highlights[this.palette];
        vm.n("pauseOpacity").value=vm.b("paused").value?0:1;vm.n("playOpacity").value=vm.b("paused").value?1:0;
        vm.n("markSize").value=Math.min(56,440/Math.max(1,vm.s("mark").value.length*1.05));vm.s("patternLabel").value=patternNames[this.pattern];
    }
    override advance(dt:f64):bool {
        if(!this.ready)return true;
        let vm=this.vm!,sheet=this.sheet!,art=sheet.art!,entry=this.entry!;
        if(this.layoutDirty){
            this.compact=this.w/this.h<1.12;sheet.w=this.compact?470:620;sheet.h=this.compact?748:980;art.width=sheet.w;art.height=sheet.h;
            let values=this.compact?phone:desktop;for(let i=0;i<reflowNames.length;i++)vm.n(reflowNames[i]).value=values[i];
            art.advance(0);sheet.canvas.resize(<u32>(sheet.w*2),<u32>(sheet.h*2));this.stage!.bind(sheet);
            vm.n("calloutX").value=this.w-218;vm.n("calloutY").value=this.h*.45-14;vm.n("footerY").value=this.h-140;
            this.headerArt!.width=Math.max(300,this.w-80);this.headerArt!.advance(0);
            this.back!.w=sheet.w;this.back!.h=sheet.h;this.front!.w=sheet.w;this.front!.h=sheet.h;this.layoutDirty=false;
        }
        this.sync();entry.blink+=dt;
        let step=vm.b("paused").value?0:dt*this.speed;this.t+=step;
        for(let i=0;i<this.patterns.length;i++)this.patterns[i].advance(step);
        art.advance(dt);this.markArt!.advance(dt);this.headerArt!.advance(dt);this.letterArt!.advance(dt);
        if(vm.b("reduceMotion").value){this.tiltX=0;this.tiltY=0;}
        else if(!this.capture && !this.flexing && !this.dragging && this.slider==""){
            let follow=1-Math.exp(-dt*5.5);this.tiltX+=(this.hoverX-this.tiltX)*follow;this.tiltY+=(this.hoverY-this.tiltY)*follow;
            if(Math.abs(this.hoverX-this.tiltX)<.00001)this.tiltX=this.hoverX;if(Math.abs(this.hoverY-this.tiltY)<.00001)this.tiltY=this.hoverY;
        }
        let a=1-Math.exp(-dt*6);this.flat+=((vm.b("flat").value?1:0)-this.flat)*(1-Math.exp(-dt*2.5));this.pull+=(vm.n("pull").value-this.pull)*a;
        this.scrollFlex+=(Math.abs(this.scrollVelocity)*.003-this.scrollFlex)*(1-Math.exp(-dt*8));this.scrollVelocity*=Math.exp(-dt*8);
        this.yaw+=(vm.n("orbitYaw").value-this.yaw)*a;this.pitch+=(vm.n("orbitPitch").value-this.pitch)*a;
        if(this.reveal>0){this.reveal+=dt*.65;if(this.reveal>1.5)this.reveal=0;}vm.n("reveal").value=this.reveal;
        let hoverPos=this.hoverPos,hoverPoint:Hit?=null;if(hoverPos!=null)hoverPoint=hit(sheet,hoverPos.position,this.w,this.h);
        let micro=this.micro!,hover=micro.pick(hoverPoint,sheet.w,vm.n("sheetPadSide").value,vm.n("listHeight").value,vm.n("trackWidth").value);
        micro.update(dt,this.pattern,this.palette,<i32>vm.n("tab").value,vm.b("paused").value,entry.active,hover,this.microPress,vm.b("reduceMotion").value);
        return true;
    }
    matrices():void {
        let w=this.w,h=this.h;this.compact=w/h<1.12;let unit=Math.min(w/1600,h/900),camera=view(w,h,this.tiltX,this.tiltY),distance=camera.distance;
        this.eye=camera.eye;this.vp=camera.vp;let sheet=this.sheet!,stage=this.stage!;
        let sheetModel=Mat4.identity(),bend=clamp((1-this.flat)*(1+this.pull*.7+this.scrollFlex),0,1.5),sx:f64=0,sy:f64=0,size:f64=0;
        if(this.compact){
            let top=Math.min(310,h*.32),ps=Math.min((w-34)/(sheet.w+80),(h-top-24)/sheet.h);
            sheetModel=translate(w*.41-w/2,h/2-(top+sheet.h*ps*.5),0)*scale(ps,-ps,ps);sx=w*.47;sy=150;size=w*.40;bend*=.32;
        }else{
            let s=(.90-.11*this.flat)*unit;
            sheetModel=translate(w*.197-w/2+30*unit*(1-this.flat)+100*unit*this.flat,-45*unit+80*unit*this.flat,-20*unit)*scale(s,-s,s);
            sheetModel=translate(0,0,distance*.16)*scale(.84,.84,.84)*sheetModel;sx=w*.665;sy=h*.46;size=425*unit;
        }
        let rotation=Mat4.fromRotationZ(<f32>(this.compact?-.12:-.28))*Mat4.fromRotationY(<f32>((this.compact?-.65:-.85)+this.yaw))*Mat4.fromRotationX(<f32>((this.compact?.65:.4)+this.pitch))*scale(size,size,size);
        let top=-220*unit,cy=this.compact?h/2-sy:top-this.shoe!.bottom(rotation)+2*unit;this.model=translate(sx-w/2,cy,60*unit)*rotation;
        stage.update(this.vp,this.eye,Math.max(unit,.45),sx-w/2+85*unit,top,10*unit,460*unit,320*unit,w*this.renderScale,h*this.renderScale);
        let sheets=[sheet,this.back!,this.front!];for(let i=0;i<sheets.length;i++)stage.place(sheets[i],this.vp,sheetModel,bend,this.t,1,0,this.eye);
        let row=sheet.art!.node("Choose "+patternNames[this.pattern]);let q=xy(sheet.w-50,310);
        if(row!=null){q=row.worldTransform().transformPoint(xy(sheet.w-105,41));row.release();}
        let localStart=point(q.x/sheet.w,clamp(q.y/sheet.h,.25,.61),sheet.w,sheet.h,bend);
        let start=sheetModel.transformPoint(localStart.x,localStart.y,localStart.z),finish=this.model.transformPoint(-.65,-.12,.26);
        stage.place(this.bridge!,this.vp,Mat4.identity(),0,this.t,this.reveal>0?.9:0,this.reveal,start,finish);
        floats(this.studioBuf,0,[w,h,this.t,0,.76,.83,.35,.05]);this.studioUbo!.update(0,this.studioBuf);
    }
    override draw(renderer:Renderer):void {
        if(!this.ready)return;
        let gpu=this.gpu!,stage=this.stage!,sheet=this.sheet!,shoe=this.shoe!;
        if(this.dirty){
            let max=this.context!.features().maxTextureSize2D;this.renderScale=Math.min(this.dpr,Math.min(max/this.w,max/this.h));
            let pw=<u32>Math.floor(this.w*this.renderScale),ph=<u32>Math.floor(this.h*this.renderScale);gpu.resize(pw,ph);
            if(this.depthView!=null)this.depthView!.release();if(this.depth!=null)this.depth!.release();if(this.msaaView!=null)this.msaaView!.release();if(this.msaa!=null)this.msaa!.release();if(this.resolveView!=null)this.resolveView!.release();
            this.depth=texture(pw,ph,TextureFormat.depth32float,4);this.depthView=this.depth!.view();this.msaa=texture(pw,ph,<TextureFormat>gpu.format,4);this.msaaView=this.msaa!.view();this.resolveView=gpu.colorView();this.dirty=false;
        }
        this.matrices();
        let pr=this.patternCanvas!.beginFrame()!;pr.transform(Mat2D.withUniformScale(3));this.patterns[this.pattern].draw(pr);this.patternCanvas!.endFrame();
        let mr=this.markCanvas!.beginFrame()!;mr.transform(Mat2D.withUniformScale(2));this.markArt!.draw(mr);this.markCanvas!.endFrame();
        if(!this.letterReady){let lr=this.letterCanvas!.beginFrame()!;this.letterArt!.draw(lr);this.letterCanvas!.endFrame();this.letterReady=true;}
        let rr=sheet.canvas.beginFrame()!;rr.transform(Mat2D.withUniformScale(2));sheet.art!.draw(rr);let field=sheet.art!.node("Mark field");this.entry!.draw(rr,field,sheet.w-2*this.vm!.n("sheetPadSide").value);if(field!=null)field.release();sheet.canvas.endFrame();
        shoe.update(this.vp,this.model,this.eye,this.patternScale,stage,palettes[this.palette],this.reveal);
        let shadowDesc=new GPUPassDesc();shadowDesc.depthView=stage.shadowView;shadowDesc.depthStoreOp=StoreOp.store;
        let shadow=gpu.beginRenderPass(shadowDesc);stage.shadowSurface(sheet,shadow);stage.shadowSurface(this.back!,shadow);
        if(!this.compact){stage.shadowSurface(this.front!,shadow);stage.shadowPlinth(shadow);}shoe.draw(shadow,true);shadow.finish();
        let desc=new GPUPassDesc(),color=new GPUColorAttachment();color.view=this.msaaView;color.resolveTarget=this.resolveView;color.storeOp=StoreOp.discard;color.clearR=.98;color.clearG=.99;color.clearB=.7;
        desc.color=[color];desc.depthView=this.depthView;desc.depthStoreOp=StoreOp.store;
        let pass=gpu.beginRenderPass(desc);pass.setPipeline(this.studioPipeline!);pass.setBindGroup(0,this.studioBg!);pass.draw(3);
        if(!this.compact)stage.drawEnvironment(pass);stage.drawSurface(this.back!,pass);shoe.draw(pass);stage.drawSurface(sheet,pass);if(!this.compact)stage.drawSurface(this.front!,pass);if(this.reveal>0)stage.drawSurface(this.bridge!,pass);pass.finish();
        renderer.save();renderer.transform(Mat2D.withUniformScale(<f32>(1/this.renderScale)));renderer.drawImage(gpu.image,ImageSampler(),BlendMode.srcOver,1);renderer.restore();
        renderer.save();renderer.transform(Mat2D.withTranslation(38,14));this.headerArt!.draw(renderer);renderer.restore();
    }
    updateSlider(q:Vector):void {
        let p=nodePoint(this.sheet!.art!,this.slider+" vector slider",q);if(p==null)return;
        let v=clamp(p.x/this.vm!.n("trackWidth").value,0,1);this.vm!.n(this.slider=="Scale"?"scale":"speed").value=this.slider=="Scale"?.5+v*2.5:v*2;
    }
    pointer(event:PointerEvent,kind:string):void {
        if(!this.ready)return;this.matrices();let sheet=this.sheet!,art=sheet.art!,vm=this.vm!,entry=this.entry!;
        let q=hit(sheet,event.position,this.w,this.h),inside=q!=null && q.x>=0 && q.x<=sheet.w && q.y>=0 && q.y<=sheet.h;
        if(kind=="down"){
            this.microPress=this.micro!.pick(q,sheet.w,vm.n("sheetPadSide").value,vm.n("listHeight").value,vm.n("trackWidth").value);
            let clickedEntry=false;this.pressPoint=event.position;this.moved=false;this.last=event.position;
            if(inside && q!=null){
                let pull=nodePoint(art,"Lift the paper",q.position);
                if(pull!=null && pull.y>=-6 && pull.y<=36 && pull.x>=-20){this.flexing=true;this.pullStart=vm.n("pull").value;}
                else{
                    let field=nodePoint(art,"Mark field",q.position);
                    if(field!=null && field.x>=0 && field.x<sheet.w-2*vm.n("sheetPadSide").value && field.y>=0 && field.y<43){entry.click(field.x);clickedEntry=true;}
                    for(let i=0;i<2;i++){let name=i==0?"Scale":"Motion",p=nodePoint(art,name+" vector slider",q.position);if(p!=null && p.x>=-12 && p.x<vm.n("trackWidth").value+12 && p.y>=0 && p.y<34){this.slider=name;this.updateSlider(q.position);break;}}
                    if(this.slider=="")art.pointerDown(new PointerEvent(event.id,q.position));this.capture=true;
                }
            }else this.dragging=true;
            if(!clickedEntry)entry.active=false;
        }else if(kind=="move"){
            if(!this.capture && !this.flexing && !this.dragging && this.slider==""){
                if(event.position.x<0 || event.position.x>this.w || event.position.y<0 || event.position.y>this.h){this.hoverPos=null;this.hoverX=0;this.hoverY=0;}
                else{this.hoverPos=new Hit(event.position);this.hoverX=clamp(event.position.x/this.w*2-1,-1,1);this.hoverY=clamp(event.position.y/this.h*2-1,-1,1);}
            }
            if(this.capture || this.flexing){let d=event.position-this.pressPoint;if(d.lengthSquared()>64)this.moved=true;}
            if(this.flexing)vm.n("pull").value=clamp(this.pullStart+(this.pressPoint.y-event.position.y)/180,0,1);
            else if(this.slider!="" && q!=null)this.updateSlider(q.position);
            else if(this.capture && q!=null){art.pointerMove(new PointerEvent(event.id,q.position));this.scrollVelocity=clamp(event.position.y-this.last.y,-30,30);}
            else if(this.dragging){vm.n("orbitYaw").value+=(event.position.x-this.last.x)/300;vm.n("orbitPitch").value=clamp(vm.n("orbitPitch").value+(event.position.y-this.last.y)/450,-.35,.5);}
            else if(inside && q!=null)art.pointerMove(new PointerEvent(event.id,q.position));
            else art.pointerExit(new PointerEvent(event.id,xy(-10,-10)));
            this.last=event.position;
        }else if(kind=="up"){
            this.microPress="";if(this.flexing && !this.moved)vm.b("flat").value=!vm.b("flat").value;
            if(this.capture && this.slider=="" && q!=null){art.pointerUp(new PointerEvent(event.id,q.position));art.advance(0);if(this.moved){let a=vm.n("action");if(a.value>=1 && a.value<=4)a.value=0;}}
            vm.n("pull").value=0;this.slider="";this.capture=false;this.dragging=false;this.flexing=false;
        }
        event.hit();
    }
    override pointerDown(e:PointerEvent):void{this.pointer(e,"down");}
    override pointerMove(e:PointerEvent):void{this.pointer(e,"move");}
    override pointerUp(e:PointerEvent):void{this.pointer(e,"up");}
    override pointerExit(e:PointerEvent):void{this.hoverX=0;this.hoverY=0;this.hoverPos=null;if(this.ready && !this.capture && !this.flexing){this.sheet!.art!.pointerExit(e);this.dragging=false;}}
    override keyboardEvent(e:KeyboardEvent):bool {
        if(!this.ready)return false;if(this.entry!.active)return this.entry!.key(e);let vm=this.vm!;
        if(e.phase=="down"){
            if(e.key==32){vm.b("paused").value=!vm.b("paused").value;return true;}
            if(e.key==70){vm.b("flat").value=!vm.b("flat").value;return true;}
            if(e.key==77){vm.b("reduceMotion").value=!vm.b("reduceMotion").value;return true;}
            if(e.key==82){vm.n("orbitYaw").value=0;vm.n("orbitPitch").value=0;this.hoverX=0;this.hoverY=0;this.hoverPos=null;return true;}
        }return false;
    }
    override textEvent(e:TextInput):bool{return this.ready && this.entry!.text(e);}
}
