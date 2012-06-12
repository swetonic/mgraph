(function() {

    Ext.require('Ext.slider.*');

    Ext.onReady(function(){
        var sliderComponent = null;
        
        var slider = Ext.create('Ext.slider.Single', {
            renderTo: 'tip-slider',
            hideLabel: true,
            width: 180,
            minValue: 2,
            value: 4,
            maxValue: 7,
        });
        
        slider.addListener("changecomplete", function(slider, newValue, thumb) {
            //clear the relationships, then make another ajax call
            updateCollaborators(newValue);
        });
        
        
    });

  packages = {

    // Lazily construct the package hierarchy from class names.
    root: function(classes) {
      var map = {};

      function find(name, data) {
        var node = map[name], i;
        if (!node) {
          node = map[name] = data || {name: name, children: []};
          if (name.length) {
            node.parent = find(name.substring(0, i = name.lastIndexOf(".")));
            node.parent.children.push(node);
            node.key = name.substring(i + 1);
          }
        }
        return node;
      }

      classes.forEach(function(d) {
        find(d.name, d);
      });

      return map[""];
    },

    // Return a list of imports for the given array of nodes.
    imports: function(nodes) {
      var map = {},
          imports = [];

      // Compute a map from name to node.
      nodes.forEach(function(d) {
        map[d.data.name] = d;
      });

      // For each import, construct a link from the source to target node.
      nodes.forEach(function(d) {
        if (d.data.imports) d.data.imports.forEach(function(i) {
          imports.push({source: map[d.data.name], target: map[i]});
        });
      });

      return imports;
    }

  };
})();