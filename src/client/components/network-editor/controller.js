import EventEmitter from 'eventemitter3';
import { styleFactory, LinearColorStyleValue, LinearNumberStyleValue, NumberStyleStruct, ColorStyleStruct } from '../../../model/style'; // eslint-disable-line
import { CytoscapeSyncher } from '../../../model/cytoscape-syncher'; // eslint-disable-line
import Cytoscape from 'cytoscape'; // eslint-disable-line
import Color from 'color'; // eslint-disable-line
import { VizMapper } from '../../../model/vizmapper'; //eslint-disable-line
import { DEFAULT_NODE_STYLE, DEFAULT_EDGE_STYLE } from '../../../model/style';

/**
 * The network editor controller contains all high-level model operations that the network
 * editor view can perform.
 * 
 * @property {Cytoscape.Core} cy The graph instance
 * @property {CytoscapeSyncher} cySyncher The syncher that corresponds to the graph instance
 * @property {EventEmitter} bus The event bus that the controller emits on after every operation
 * @property {VizMapper} vizmapper The vizmapper for managing style
 */
export class NetworkEditorController {
  /**
   * Create an instance of the controller
   * @param {Cytoscape.Core} cy The graph instance (model)
   * @param {CytoscapeSyncher} cySyncher The syncher that corresponds to the Cytoscape instance
   * @param {EventEmitter} bus The event bus that the controller emits on after every operation
   */
  constructor(cy, cySyncher, bus){
    /** @type {Cytoscape.Core} */
    this.cy = cy;

    /** @type {CytoscapeSyncher} */
    this.cySyncher = cySyncher;

    /** @type {VizMapper} */
    this.vizmapper = this.cy.vizmapper(); 

    /** @type {EventEmitter} */
    this.bus = bus || new EventEmitter();

    this.drawModeEnabled = false;
  }

  /**
   * Replaces the current network with the passed one.
   * @param {Object} [elements] Cytoscape elements object
   * @param {Object} [data] Cytoscape data object
   * @param {Object} [style] Optional Cytoscape Style object
   */
  setNetwork(elements, data, style) {
    this.cy.elements().remove();
    this.cy.removeData();
    
    this.cy.add(elements);
    this.cy.data(data);

    if (style) {
      // TODO: This convertions are only necessary until we receive the correct Style object ====
      // Let's just convert a few for testing purpose...
      style.defaults.map((el) => {
        const { visualProperty: k, value: v } = el;

        if (k === "NODE_FILL_COLOR")
          this.cySyncher.setStyle('node', 'background-color', styleFactory.color(v));
        else if (k === "EDGE_STROKE_UNSELECTED_PAINT")
          this.cySyncher.setStyle('edge', 'line-color', styleFactory.color(v));
      });
      // ========================================================================================
    }

    // Do not apply any layout if at least one original node has a 'position' object
    const nodes = elements.nodes;
    const hasPositions = nodes && nodes.length > 0 && nodes[0].position != null;

    if (hasPositions) {
      this.cy.fit();
    } else {
      const layout = this.cy.layout({ name: 'grid' });
      layout.run();
    }

    this.bus.emit('setNetwork', this.cy);
  }

  /**
   * Add a new node to the graph
   */
  addNode() {
    function randomArg(... args) {
      return args[Math.floor(Math.random() * args.length)];
    }
    const node = this.cy.add({
      renderedPosition: { x: 100, y: 50 },
      data: {
        attr1: Math.random(), // betwen 0 and 1
        attr2: Math.random() * 2.0 - 1.0, // between -1 and 1
        attr3: randomArg("A", "B", "C")
      }
    });

    this.bus.emit('addNode', node);
  }

  /**
   * Toggle whether draw mode is enabled
   * @param {Boolean} [bool] A boolean override (i.e. force enable on true, force disable on false)
   */
  toggleDrawMode(bool = !this.drawModeEnabled){
    if( bool ){
      this.eh.enableDrawMode();

      this.bus.emit('enableDrawMode');
    } else {
      this.eh.disableDrawMode();
      this.bus.emit('disableDrawMode');
    }

    this.drawModeEnabled = bool;

    /**
     * toggleDrawMode event
     * @event NetworkEditorController#toggleDrawMode
     * @argument {Boolean} bool Whether draw mode has been enabled (true) or disabled (false)
     */
    this.bus.emit('toggleDrawMode', bool);
  }

  /**
   * Enable draw mode
   */
  enableDrawMode(){
    return this.toggleDrawMode(true);
  }

  /**
   * Disable draw mode
   */
  disableDrawMode(){
    this.toggleDrawMode(false);
  }

  /**
   * Delete the selected (i.e. :selected) elements in the graph
   */
  deletedSelectedElements(){
    const deletedEls = this.cy.$(':selected').remove();

    this.bus.emit('deletedSelectedElements', deletedEls);
  }

  /**
   * Get the list of data attributes that exist on the nodes
   * @returns {Array<String>} An array of public attribute names
   */
  getPublicAttributes() {
    const attrNames = new Set();
    const nodes = this.cy.nodes();
    
    nodes.forEach(n => {
      const attrs = Object.keys(n.data());
      attrs.forEach(a => {
        attrNames.add(a);
      });
    });

    return Array.from(attrNames);
  }

  /**
   * 
   * @param {String} selector The cyjs selector, 'node' or 'edge'.
   * @param {String} attribute The data attribute name.
   */
  getDiscreteValueList(selector, attribute) {
    const eles = this.cy.elements(selector);
    const vals = eles.map(ele => ele.data(attribute));
    const res  = [...new Set(vals)].sort().filter(x => x !== undefined);
    return res;
  }


  /**
   * Return the discrete default mapping value.
   * @param {String} selector 'node' or 'edge'
   * @param {String} property a style property that expects a color value, such as 'background-color'
   * @return {Any} the discrete default mapping value
   */
  getDiscreteDefault(selector, property) {
    if(selector === 'node')
      return DEFAULT_NODE_STYLE[property].value;
    else if(selector === 'edge')
      return DEFAULT_EDGE_STYLE[property].value;
  }

  /**
   * Get the global style
   * @param {String} selector The selector to get style for ('node' or 'edge')
   * @param {String} property The style property name
   */
  getStyle(selector, property) {
    return this.vizmapper.get(selector, property);
  }

  /**
   * Set a color propetry of all elements to single color.
   * @param {String} selector 'node' or 'edge'
   * @param {String} property a style property that expects a color value, such as 'background-color'
   * @param {(Color|String)} color The color to set
   */
  setColor(selector, property, color) {
    this.vizmapper.set(selector, property, styleFactory.color(color));
    this.bus.emit('setColor', selector, property, color);
  }

  /**
   * Set the color of all elements to a linear mapping
   * @param {String} selector 'node' or 'edge'
   * @param {String} property a style property that expects a color value, such as 'background-color'
   * @param {String} attribute The data attribute to map
   * @param {LinearColorStyleValue} value The style mapping struct value to use as the mapping
   */
  setColorLinearMapping(selector, property, attribute, value) {
    const {hasVal, min, max} = this._minMax(attribute, this.cy.nodes());
    if(!hasVal)
      return;
    const style = styleFactory.linearColor(attribute,  min,  max, value.styleValue1, value.styleValue2);
    this.vizmapper.set(selector, property, style);
    this.bus.emit('setColorLinearMapping', selector, property, attribute, value);
  }

  /**
   * Set the color of all elements to a discrete mapping
   * @param {String} attribute The data attribute to map
   * @param {DiscreteColorStyleValue} valueMap The style mapping struct value to use as the mapping
   */
  setColorDiscreteMapping(selector, property, attribute, valueMap) {
    // TODO Allow user to set default value?
    const defaultValue = this.getDiscreteDefault(selector, property);
    const style = styleFactory.discreteColor(attribute, defaultValue, valueMap);
    this.vizmapper.set(selector, property, style);
    this.bus.emit('setColorDiscreteMapping', selector, property, attribute, valueMap);
  }
  
  /**
   * Set a numeric propetry of all elements to single value.
   * @param {String} selector 'node' or 'edge'
   * @param {String} property a style property that expects a numeric value
   * @param {Number} value The value to set
   */
  setNumber(selector, property, value) {
    this.vizmapper.set(selector, property, styleFactory.number(value));
    this.bus.emit('setNumber', selector, property, value);
  }

  /**
   * Set the numeric property of all elements to a linear mapping
   * @param {String} selector 'node' or 'edge'
   * @param {String} property a style property that expects a numeric value.
   * @param {String} attribute The data attribute to map
   * @param {LinearColorStyleValue} value The style mapping struct value to use as the mapping
   */
  setNumberLinearMapping(selector, property, attribute, value) {
    const {hasVal, min, max} = this._minMax(attribute, this.cy.nodes());
    if(!hasVal)
      return;
    const style = styleFactory.linearNumber(attribute,  min,  max, value.styleValue1, value.styleValue2);
    this.vizmapper.set(selector, property, style);
    this.bus.emit('setNumberLinearMapping', selector, property, attribute, value);
  }

  /**
   * Set the numeric value of all elements to a discrete mapping
   * @param {String} selector 'node' or 'edge'
   * @param {String} property a style property that expects a numeric value.
   * @param {String} attribute The data attribute to map
   * @param {DiscreteColorStyleValue} valueMap The style mapping struct value to use as the mapping
   */
  setNumberDiscreteMapping(selector, property, attribute, valueMap) {
    // TODO Allow user to set default value?
    const defaultValue = this.getDiscreteDefault(selector, property);
    const style = styleFactory.discreteNumber(attribute, defaultValue, valueMap);
    this.vizmapper.set(selector, property, style);
    this.bus.emit('setNumberDiscreteMapping', selector, property, attribute, valueMap);
  }

  /**
   * Set a string propetry of all elements to single value.
   * @param {String} selector 'node' or 'edge'
   * @param {String} property a style property that expects a string value
   * @param {Number} text The value to set
   */
  setString(selector, property, text) {
    this.vizmapper.set(selector, property, styleFactory.string(text));
    this.bus.emit('setString', selector, property, text);
  }

/**
   * Set a string propetry of all elements to single value.
   * @param {String} selector 'node' or 'edge'
   * @param {String} property a style property that expects a string value
   * @param {String} attribute The data attribute to map
   */
  setStringPassthroughMapping(selector, property, attribute) {
    this.vizmapper.set(selector, property, styleFactory.stringPassthrough(attribute));
    this.bus.emit('setStringPassthroughMapping', selector, property, attribute);
  }

  /**
   * Returns the min and max values of a numeric attribute.
   * @private
   */
  _minMax(attribute, eles) {
    eles = eles || this.cy.elements();
    let hasVal = false;
    let min = Number.POSITIVE_INFINITY; 
    let max = Number.NEGATIVE_INFINITY;

    // compute min and max values
    eles.forEach(ele => {
      const val = ele.data(attribute);
      if(val) {
        console.log(val);
        hasVal = true;
        min = Math.min(min, val);
        max = Math.max(max, val);
      }
    }); 

    return {hasVal, min, max};
  }
  
}
