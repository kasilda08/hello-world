<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <title>Voronoï playground: Voronoï transitioning thanks to weighted Voronoï</title>
    <meta name="description" content="Transitioning from one Voronoï tessellation to another thanks to Weighted Voronoï, using D3.js and the d3-weighted-voronoi plugin">
    <script src="https://d3js.org/d3.v4.min.js" charset="utf-8"></script>
    <script src="https://rawcdn.githack.com/Kcnarf/d3-weighted-voronoi/v1.0.0/build/d3-weighted-voronoi.js"></script>
    
    <style>
      #wip {
        display: none;
        position: absolute;
        top: 200px;
        left: 330px;
        font-size: 40px;
        text-align: center;
      }


      .control {
        position: absolute;
        top: 5px;
      }
      .control#control-0 {
        left: 5px;
        text-align: center;
      }
      .control#control-1 {
        left: 5px;
        top: 25px;
      }
      .control#control-2 {
        right: 460px;
        top: 25px;
      }
      .control span {
        width: 100px;
      }
      .control input[type="range"] {
        width: 210px;
      }

      svg {
        position: absolute;
        top: 25px;
        left: 15px;
        margin: 1px;
        border-radius: 1000px;
        box-shadow: 2px 2px 6px grey;
      }


      #site-container {
        clip-path: url("#clipper");
      }
      .seed {
        fill: steelblue;
      }
      .seed.group-green {
        fill: lightgreen;
      }
      .seed.hide {
        display: none;
      }


      .cell {
        fill-opacity: 0.1;
        fill: lightsteelBlue;
        stroke: lightsteelBlue;
      }
      .cell.group-green {
        fill: lightgreen;
        stroke: lightgreen;
      }
    </style>
  </head>
  <body>

    <svg>
      <defs>
        <clipPath id="clipper">
          <rect x="0" y="0" width="960" height="500" />
        </clipPath>
      </defs>
      <g id="drawing-area">
        <g id="cell-container"></g>
        <g id="site-container"></g>
      </g>
    </svg>
    
    <div id="control-0" class="control">
      <span>Voronoï of blue sites</span>
      <input id="weight" type="range" name="points" min="-5000" max="5000" value="0" oninput="weightUpdated()">
      <span>Voronoï of green sites</span>
    </div>
    <div id="control-1" class="control">
      <span>Show blue sites</span>
      <input id="weight" type="checkbox" name="showSites" onchange="blueSiteVisibilityUpdated()">
    </div>
    <div id="control-2" class="control">
      <input id="weight" type="checkbox" name="showSites" onchange="greenSiteVisibilityUpdated()">
      <span>Show green sites</span>
    </div>

    <div id="wip">
      Work in progress ...
    </div>
  </body>

  <script>
    var WITH_TRANSITION = true;
    var WITHOUT_TRANSITION = false;
    var duration = 250;
    var _2PI = 2*Math.PI;

    //begin: layout conf.
    var totalHeight = 500,
        controlsHeight = 30,
        svgRadius = (totalHeight-controlsHeight)/2,
        svgbw = 1, //svg border width
        svgHeight = 2*svgRadius,
    		svgWidth = 2*svgRadius,
        radius = svgRadius-svgbw,
        width = 2*svgRadius,
        height = 2*svgRadius,
        halfRadius = radius/2
        halfWidth = halfRadius,
        halfHeight = halfRadius,
        quarterRadius = radius/4;
        quarterWidth = quarterRadius,
        quarterHeight = quarterRadius;
    //end: layout conf.

    //begin: voronoi stuff definitions
    var siteCount = 120,
        quarterSiteCount = siteCount/4;
    var blueSites = [],
        greenSites = [];
    var baseWeight = 10000,
        x, y;
    for (i=0; i<quarterSiteCount; i++) {
      //use (x,y) instead of (r,a) for a better uniform (ie. less centered) placement of sites
      x = width*Math.random();
      y = height*Math.random();
      while (Math.sqrt(Math.pow(x-radius,2)+Math.pow(y-radius,2))>radius) {
        x = width*Math.random();
      	y = height*Math.random();
      }
      blueSites.push({index: i, group: "blue", x: x, y: y, weight: baseWeight});
      
      [0,1,2].forEach(function () {
        x = width*Math.random();
        y = height*Math.random();
        while (Math.sqrt(Math.pow(x-radius,2)+Math.pow(y-radius,2))>radius) {
          x = width*Math.random();
          y = height*Math.random();
        }
        greenSites.push({index: i+siteCount, group: "green", x: x, y: y, weight: baseWeight});
      })
    }
    var	sites = blueSites.concat(greenSites);
    var clippingPolygon = [[0,0], [0,height], [width,height], [width,0]];
    var weightedVoronoi = d3.weightedVoronoi().clip(clippingPolygon);
    var cells = sites.map(function(s){ return []; });	// stores, for each site, each cell's verteces
    //end: voronoi stuff definitions

    //begin: utilities
    var cellLiner = d3.line()
    .x(function(d){ return d[0]; })
    .y(function(d){ return d[1]; });
    //end: utilities

    //begin: reusable d3-selections
    var svg = d3.select("svg"),
        clipper = d3.select("#clipper>rect"),
        drawingArea = d3.select("#drawing-area"),
        cellContainer = d3.select("#cell-container"),
        siteContainer = d3.select("#site-container");
    //end: reusable d3-selections

    //begin: user interaction handlers
    function weightUpdated() {
      var deltaWeight,
          newBlueWeigth,
          newGreenWeight;
      deltaWeight = +d3.select("#control-0 input").node().value;
      newBlueWeigth = baseWeight - deltaWeight;
      newGreenWeight = baseWeight + deltaWeight;

      blueSites.forEach(function(s){ s.weight = newBlueWeigth });
      greenSites.forEach(function(s){ s.weight = newGreenWeight });
      computeAllCells();

      redrawAllCells(WITHOUT_TRANSITION);
    }
    
    function blueSiteVisibilityUpdated() {
      visibility = d3.select("#control-1 input").node().checked? 1:0;
      redrawGroup("blue", visibility , WITH_TRANSITION);
    }
    
    function greenSiteVisibilityUpdated() {
      visibility = d3.select("#control-2 input").node().checked? 1:0;
      redrawGroup("green", visibility, WITH_TRANSITION);
    }
    //end: user interaction handlers

    computeAllCells();

    initLayout();
    redrawAllCells(WITHOUT_TRANSITION);

    /***************/
    /* Computation */
    /***************/

    function computeAllCells() {
      cells = weightedVoronoi(sites);
    }

    /***********/
    /* Drawing */
    /***********/

    //redraw group = show/hide sites of particular group
    function redrawGroup(color, finalOpacity, withTransition) {
      siteContainer.selectAll(".seed").filter(function(d){ return d.group === color; })
        .transition()
          .duration(withTransition? duration : 0)
          .attr("opacity", finalOpacity);
    }

    function redrawAllCells(withTransition) {
			var cellSelection = cellContainer.selectAll(".cell")
        .data(cells, function(c){ return c.site.originalObject.index; });
      
      cellSelection.enter()
        .append("path")
          .attr("class", function(d){ return "group-"+d.site.originalObject.group; })
          .classed("cell", true)
          .attr("id", function(d,i){ return "cell-"+d.site.originalObject.index; })
      	.merge(cellSelection)
      		.transition()
            .duration(withTransition? duration : 0)
            .attr("d", function(d){ return cellLiner(d)+"z"; });
      
      cellSelection.exit().remove();
    }

    function initLayout () {
      svg.attr("width", svgWidth)
        .attr("height", svgHeight);

      clipper.attr("x", 0)
        .attr("y", 0)
        .attr("width", width)
        .attr("height", height);

      drawingArea.attr("width", width)
        .attr("height", height)
        .attr("transform", "translate("+[svgbw, svgbw]+")");

      //begin: draw sites
      var drawnSites = siteContainer.selectAll(".site")
      .data(sites)
      .enter()
        .append("g")
          .attr("id", function(d){ return "site-"+d.index})
          .classed("site", true);
      drawnSites.append("circle")
        .attr("id", function(d,i){ return "seed-"+i; })
        .attr("class", function(d){ return "group-"+d.group; })
        .classed("seed", true)
        .attr("r", 2)
      	.attr("opacity", 0)
      	.attr("transform", function(d){ return "translate("+[d.x,d.y]+")"; });;
      //end: draw sites

      //begin: draw cells
      cellContainer.selectAll(".cell")
        .data(cells)
        .enter()
        .append("path")
        .attr("class", function(d){ return "group-"+d.site.originalObject.group; })
        .classed("cell", true)
        .attr("id", function(d,i){ return "cell-"+d.site.originalObject.index; });
      //end: draw cells
    }
  </script>
</html>
