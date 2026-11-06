"""TEMPORARY persona-review helper (not part of the app).

Injects a fake clock into build/web/index.html so the web build can be
driven through a whole day. Run after `flutter build web -t tool/persona_main.dart`.

    python tool/inject_fake_clock.py            # clock starts 07:45 today
    python tool/inject_fake_clock.py 13 50      # clock starts 13:50 today

In the browser console:  __setClock(10, 55)  jumps the clock (data kept);
__clock() prints the fake time. Dart's DateTime.now() reads Date.now().
"""
import datetime
import pathlib
import sys

h = int(sys.argv[1]) if len(sys.argv) > 1 else 7
m = int(sys.argv[2]) if len(sys.argv) > 2 else 45
d = datetime.date.today()
y, mo, dd = d.year, d.month - 1, d.day  # JS months are 0-based

p = pathlib.Path(__file__).resolve().parent.parent / "build" / "web" / "index.html"
s = p.read_text(encoding="utf-8")
if "__setClock" in s:
    sys.exit("Already injected; rebuild first.")
inj = f"""<script>
(function(){{var R=Date.now.bind(Date);var off=new Date({y},{mo},{dd},{h},{m},0).getTime()-R();
Date.now=function(){{return R()+off}};
var O=Date;function F(){{if(!(this instanceof F))return new O(Date.now()).toString();var a=[].slice.call(arguments);if(a.length===0)return new O(Date.now());return new (Function.prototype.bind.apply(O,[null].concat(a)))();}}
F.prototype=O.prototype;F.now=Date.now;F.UTC=O.UTC;F.parse=O.parse;window.Date=F;
window.__setClock=function(h,m){{off=new O({y},{mo},{dd},h,m||0,0).getTime()-R();return new O(Date.now()).toString()}};
window.__clock=function(){{return new O(Date.now()).toString()}};}})();
</script>"""
p.write_text(s.replace("<head>", "<head>\n" + inj, 1), encoding="utf-8")
print(f"Injected; clock starts {h:02d}:{m:02d} on {d}.")
