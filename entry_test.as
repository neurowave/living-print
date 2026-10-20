import { Tests } from "rive/test";
import { Entry } from "./entry";

function setup():Entry {return new Entry(null,"RIVE");}
function key(e:Entry,k:i32,shift:bool=false,meta:bool=false):void {e.keyInput(k,"down",shift,meta);}
function text(e:Entry,s:string):void {e.insert(s);}
export class EntryTests extends Tests {
    override run():void {
        test("entry accepts text only after focus and mirrors normalized value",(expect)=>{
            let e=setup();text(e,"BAD");expect.that(e.value).is("RIVE");e.click(20);text(e,"g-flab");expect.that(e.value).is("G-FLAB");
            key(e,263);key(e,259);text(e,"9");expect.that(e.value).is("G-FL9B");key(e,257);text(e,"BAD");expect.that(e.value).is("G-FL9B");
        });
        test("selection, limits, delete and cancellation",(expect)=>{
            let e=setup();e.click(20);text(e,"N-1234567890123456");expect.that(e.value.length).is(12);
            key(e,65,false,true);text(e,"D-JET");expect.that(e.value).is("D-JET");key(e,263,true);key(e,263,true);text(e,"X");expect.that(e.value).is("D-JX");
            key(e,268);key(e,261);expect.that(e.value).is("-JX");key(e,256);expect.that(e.value).is("RIVE");expect.that(e.active).is(false);
        });
    }
}
