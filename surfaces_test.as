import { Tests, Expect } from "rive/test";
import { Mat4 } from "rive/mat4";
import { Surface, view, point, project, hit } from "./surfaces";
import { translate, scale } from "./support";

function desktopModel():Mat4 {return translate(0,0,288)*scale(.84,.84,.84)*translate(-454.8,-45,-20)*scale(.9,-.9,.9);}
@editTime
function roundTrip(expect:Expect,p:Surface,w:f64,h:f64,us:f64[],vs:f64[]):void {
    for(let i=0;i<us.length;i++)for(let j=0;j<vs.length;j++){
        let u=us[i],v=vs[j],screen=project(p,u,v,w,h),q=hit(p,screen,w,h);
        expect.that(q!=null).is(true);
        if(q!=null)expect.that(Math.abs(q.x-u*p.w)<.3 && Math.abs(q.y-v*p.h)<.3).is(true);
    }
}
export class SurfacesTests extends Tests {
    override run():void {
        let bends:f64[]=[0,.35,1,1.45];
        for(let i=0;i<bends.length;i++){
            let bend=bends[i];
            test("projected input stays on native coordinates at bend "+bend.toString(),(expect)=>{
                let p=new Surface(620,980);p.bend=bend;p.mvp=view(1600,900,0,0).vp*desktopModel();
                roundTrip(expect,p,1600,900,[.08,.3,.62,.9],[.1,.3,.5,.7,.86,.95]);
            });
        }
        test("roll joins preserve continuous slope and curvature",(expect)=>{
            let us:f64[]=[0,.5,1],vs:f64[]=[-.12,-.10,1.12,1.14,1.20],e:f64=.001;
            for(let i=0;i<us.length;i++)for(let j=0;j<vs.length;j++){
                let u=us[i],v=vs[j],p=point(u,v,620,980,1),left=point(u,v-e,620,980,1),right=point(u,v+e,620,980,1);
                let d=(p-left)/<f32>e-(right-p)/<f32>e;
                expect.that(d.lengthSquared()<100).is(true);
                let before=(p-left*2+point(u,v-2*e,620,980,1))/<f32>(e*e);
                let after=(point(u,v+2*e,620,980,1)-right*2+p)/<f32>(e*e);
                expect.that((before-after).lengthSquared()<40000).is(true);
            }
        });
        test("paper reaches a horizontal resting section above the floor",(expect)=>{
            let us:f64[]=[0,.5,1],vs:f64[]=[1.15,1.20,1.24];
            for(let i=0;i<us.length;i++)for(let j=0;j<vs.length;j++){
                let p=point(us[i],vs[j],620,980,1),next=point(us[i],vs[j]+.001,620,980,1),worldY=-37.8-.756*p.y;
                expect.that(worldY>-290 && worldY<-285).is(true);expect.that(Math.abs(next.y-p.y)<.0001 && next.z>p.z).is(true);
            }
        });
        test("the completed floor turn remains visible inside the desktop frame",(expect)=>{
            let p=new Surface(620,980);p.mvp=view(1600,900,0,0).vp*desktopModel();let rest=project(p,1,1.14,1600,900);
            expect.that(rest.y>900*.90 && rest.y<900*.98).is(true);expect.that(rest.x>1600*.58 && rest.x<1600*.78).is(true);
        });
        test("projected phone input follows the resized native artboard",(expect)=>{
            let p=new Surface(470,748);p.bend=.32;p.mvp=view(430,932,0,0).vp*translate(-38.7,-101.52,0)*scale(.72,-.72,.72);
            roundTrip(expect,p,430,932,[.6],[.2,.45,.7,.92]);
        });
        test("curved controls remain pickable at every camera tilt extreme",(expect)=>{
            for(let size=0;size<2;size++){
                let compact=size==1,w:f64=compact?430:1600,h:f64=compact?932:900;
                let m=compact?translate(-38.7,-101.52,0)*scale(.72,-.72,.72):desktopModel();
                for(let x=-1;x<=1;x+=2)for(let y=-1;y<=1;y+=2){
                    let p=new Surface(compact?470:620,compact?748:980);p.bend=compact?.32:1;p.mvp=view(w,h,x,y).vp*m;
                    roundTrip(expect,p,w,h,[.08,.5,.9],[.2,.45,.72,.95]);
                }
            }
        });
    }
}
