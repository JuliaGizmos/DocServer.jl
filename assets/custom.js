var el = document.createElement('script');
el.src = '/pkg/WebIO/webio.bundle.js';
document.head.append(el);

var _loaded = false;
function loadliveblocks(key) {
    if (!_loaded) {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "/liveblocks/" + key);
        xhr.onreadystatechange = function () {
            if (this.readyState == 4) {
                console.log(this.response)
                var outputs = JSON.parse(this.response);
                console.log(outputs)
                for (var i=0, l=outputs.length; i<l; i++) {
                    var el = document.getElementById("live-"+ (i+1));
                    console.log(el)
                    console.log(el, outputs[i])
                    WebIO.propUtils.setInnerHtml(el, outputs[i]);
                }
            }
        }
        xhr.send();
        _loaded = true;
    }
}
