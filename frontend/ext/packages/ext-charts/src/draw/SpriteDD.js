/**
 * DD implementation for Panels.
 * @private
 */
Ext.define('Ext.draw.SpriteDD', {
    extend: 'Ext.dd.DragSource',

    constructor : function(sprite, cfg){
        var me = this,
            el = sprite.el;
        me.sprite = sprite;
        me.el = el;
        me.dragData = {el: el, sprite: sprite};
        me.callParent([el, cfg]);
        me.sprite.setStyle('cursor', 'move');
    },

    showFrame: Ext.emptyFn,
    createFrame : Ext.emptyFn,

    getDragEl : function(e){
        return this.el;
    },
    
    getRegion: function() {
        var me = this,
            el = me.el,
            pos, x1, x2, y1, y2, t, r, b, l, bbox, sprite;
        
        sprite = me.sprite;
        bbox = sprite.getBBox();
        
        try {
            pos = Ext.Element.getXY(el);
        } catch (e) { }

        if (!pos) {
            return null;
        }

        x1 = pos[0];
        x2 = x1 + bbox.width;
        y1 = pos[1];
        y2 = y1 + bbox.height;
        
        return new Ext.util.Region(y1, x2, y2, x1);
    },

    /*
      TODO(nico): Cumulative translations in VML are handled
      differently than in SVG. While in SVG we specify the translation
      relative to the original x, y position attributes, in VML the translation
      is a delta between the last position of the object (modified by the last
      translation) and the new one.
      
      In VML the translation alters the position
      of the object, we should change that or alter the SVG impl.
    */
     
    startDrag: function(x, y) {
        var me = this,
            attr = me.sprite.attr;
        me.prev = me.sprite.surface.transformToViewBox(x, y);
    },

    onDrag: function(e) {
        var xy = e.getXY(),
            me = this,
            sprite = me.sprite,
            attr = sprite.attr, dx, dy;
        xy = me.sprite.surface.transformToViewBox(xy[0], xy[1]);
        dx = xy[0] - me.prev[0];
        dy = xy[1] - me.prev[1];
        sprite.setAttributes({
            translate: {
                x: attr.translation.x + dx,
                y: attr.translation.y + dy
            }
        }, true);
        me.prev = xy;
    },

    setDragElPos: function () {
        // Disable automatic DOM move in DD that spoils layout of VML engine.
        return false;
    }
});
