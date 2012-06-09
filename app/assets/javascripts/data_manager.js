(function(){

    
    Ext.require('Ext.slider.*');

    Ext.onReady(function(){
        var sliderComponent = null;
        
        var slider = Ext.create('Ext.slider.Single', {
            renderTo: 'tip-slider',
            hideLabel: true,
            width: 180,
            minValue: 2,
            value: 4,
            maxValue: 10,
        });
        
        slider.addListener("changecomplete", function(slider, newValue, thumb) {
            maxNodes = newValue;
            updateCollaborators();
        });
        
        
    });

    Renderer = function(canvas) {
    
        canvas = $(canvas).get(0)
        var ctx = canvas.getContext("2d")
        var activeNode = null
        var mouseDown = false
        var dragging = false;
        
        var myRenderer = {
                  
            
            init:  function(system){ 
               particleSystem = system;
               particleSystem.screen({padding:[60, 60, 60, 60], // leave some space at the bottom for the param sliders
                          step:.02}) // have the ‘camera’ zoom somewhat slowly as the graph unfolds 
               $(window).resize(myRenderer.resize)
               myRenderer.resize()
               myRenderer.initMouseHandling()
            },
            
            resize:function(){
                var w = $(window).width()-60,
                    h = $(window).height()-60;
                canvas.width = w; canvas.height = h // resize the canvas element to fill the screen
                particleSystem.screenSize(w,h) // inform the system so it can map coords for us
                myRenderer.redraw()
            },
            
            initMouseHandling:function(){
                // no-nonsense drag and drop (thanks springy.js)
                selected = null;
                nearest = null;
                var dragged = null;
                var oldmass = 1
                
                $(canvas).mousedown(function(e){
                    mouseDown = true;
                    var pos = $(this).offset();
                    var p = {x:e.pageX-pos.left, y:e.pageY-pos.top}
                    selected = nearest = dragged = particleSystem.nearest(p);
                
                    if (selected.node !== null){
                        // dragged.node.tempMass = 10000
                        dragged.node.fixed = true
                    }
                    return false
                });
                
                $(canvas).mouseup(function(e){
                    if(!dragging) {
                        if(activeNode != null) {
                            clearNodes();
                            fetchMusicianCollaborators(activeNode.data.name);    
                        }
                    }
                    dragging = false;
                });
                
                $(canvas).mousemove(function(e){
                    var old_nearest = nearest && nearest.node._id
                    var pos = $(this).offset();
                    var s = {x:e.pageX-pos.left, y:e.pageY-pos.top};
                    if(mouseDown) {
                        dragging = true;
                    }

                    nearest = particleSystem.nearest(s);
                    if (!nearest) {
                        return
                    }
                    
                    if(!dragging) {
                        if(nearest.distance < 20) {
                            $(viewport).addClass("linkable");
                            activeNode = nearest.node;
                            myRenderer.drawNode(activeNode, particleSystem.toScreen(nearest.node._p))
                        }
                        else {
                            $(viewport).removeClass("linkable");
                            if(activeNode != null) {
                                var node = activeNode;
                                activeNode = null;
                                myRenderer.drawNode(node, particleSystem.toScreen(nearest.node._p))
                            }
                            activeNode = null;
                        }
                    }
                    
                    if (dragged !== null && dragged.node !== null){
                        var p = particleSystem.fromScreen(s)
                            dragged.node.p = {x:p.x, y:p.y}
                        // dragged.tempMass = 10000
                    }
                
                  return false
                  
                });
                
                $(window).bind('mouseup',function(e){
                    mouseDown = false;
                    if (dragged===null || dragged.node===undefined) {
                        return
                    }
                    else {
                        dragged.node.fixed = false
                        dragged.node.tempMass = 100
                        dragged = null;
                        selected = null
                        return false
                    }
                });
                  
            },
            
            drawNode: function(node, pt) {
              // node: {mass:#, p:{x,y}, name:"", data:{}}
              // pt:   {x:#, y:#}  node position in screen coords
              
              // determine the box size and round off the coords if we'll be 
              // drawing a text label (awful alignment jitter otherwise...)
              var w = ctx.measureText(node.data.name||"").width + 6
              var label = node.data.name
              if (!(label||"").match(/^[ \t]*$/))
              {
                pt.x = Math.floor(pt.x)
                pt.y = Math.floor(pt.y)
              }
              else
              {
                label = null
              }
              
              // clear any edges below the text label
              // ctx.fillStyle = 'rgba(255,255,255,.6)'
              // ctx.fillRect(pt.x-w/2, pt.y-7, w,14)
            
            
              ctx.clearRect(pt.x-w/2, pt.y-7, w,14)
            
              // draw the text
              if (label)
              {
                ctx.font = "bold 11px Arial"
                ctx.textAlign = "center"
                
                // if (node.data.region) ctx.fillStyle = palette[node.data.region]
                // else ctx.fillStyle = "#888888"
                if(node == activeNode) {
                    ctx.fillStyle = "#00BB00"
                }
                else {
                    ctx.fillStyle = node.data.color
                }
            
                // ctx.fillText(label||"", pt.x, pt.y+4)
                ctx.fillText(label||"", pt.x, pt.y+4)
              }
            },
            
            redraw: function() { 
                if (particleSystem===null) 
                {
                    return
                }
                
                ctx.clearRect(0,0, canvas.width, canvas.height);
                ctx.strokeStyle = "#d3d3d3"
                ctx.lineWidth = 1
                ctx.beginPath()
                
                particleSystem.eachEdge(function(edge, pt1, pt2)
                {
                  // edge: {source:Node, target:Node, length:#, data:{}}
                  // pt1:  {x:#, y:#}  source position in screen coords
                  // pt2:  {x:#, y:#}  target position in screen coords
                
                  var weight = 1 // Math.max(1,edge.data.border/100)
                  var color = "#000000" // edge.data.color
                  if (!color || (""+color).match(/^[ \t]*$/))
                  {
                    color = null
                  }
                  
                  if (color!==undefined || weight!==undefined)
                  {
                    ctx.save() 
                    ctx.beginPath()
                
                    if (!isNaN(weight)) 
                    {
                        ctx.lineWidth = weight
                    }
                    
                    if (edge.source.data.region==edge.target.data.region)
                    {
                      //ctx.strokeStyle = palette[edge.source.data.region]
                      ctx.strokeStyle = "#cdcdcd";
                    }
                    
                    // if (color) ctx.strokeStyle = color
                    ctx.fillStyle = null
                    
                    ctx.moveTo(pt1.x, pt1.y)
                    ctx.lineTo(pt2.x, pt2.y)
                    ctx.stroke()
                    ctx.restore()
                  }
                  else
                  {
                    // draw a line from pt1 to pt2
                    ctx.moveTo(pt1.x, pt1.y)
                    ctx.lineTo(pt2.x, pt2.y)
                  }
                });
                
                ctx.stroke();
                
                particleSystem.eachNode(function(node, pt)
                {
                    myRenderer.drawNode(node, pt);                    
                
                });
            
            }
        }
        
        return myRenderer;
    }
})();


    



