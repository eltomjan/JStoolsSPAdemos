function drawBarChart(ctx, xLabels, yData, labelsWidth, color) {
	function longestText(ctx,arrayOfStrings){
		var longest = 0;
		for(i in arrayOfStrings) {
			var textWidth = ctx.measureText(arrayOfStrings[i]).width;
			longest = (textWidth > longest) ? textWidth : longest;
		};
		return longest;
	}
	ctx.lineWidth = 1;
	ctx.font = "14px Arial";
	if(labelsWidth == 0) return 10 + longestText(ctx,xLabels);
	yMax = yData[0];
	for(var i=1;i<yData.length;i++) if(yMax < yData[i]) yMax = yData[i];
	graphYpos = 30;
	//xLabels
	for(var i=0;i<xLabels.length;i++)
		ctx.fillText(xLabels[i], 5, graphYpos + 30*(i+1));

	var graphXpos = labelsWidth;
	//yTicks
	ctx.textAlign = "center";
	ctx.fillText("0", graphXpos, graphYpos - 5);
	ctx.fillText(yMax, ctx.canvas.clientWidth - 20, graphYpos - 5);
	var yMultiply = (ctx.canvas.clientWidth - graphXpos - 20) / yMax;
	var ticks = [Math.round((ctx.canvas.clientWidth - graphXpos - 20) / 4), Math.round(yMax/4),
		Math.round((ctx.canvas.clientWidth - graphXpos - 20) / 2), Math.round(yMax/2), 
		Math.round(3*(ctx.canvas.clientWidth - graphXpos - 20) / 4), Math.round(3*yMax/4),
		ctx.canvas.clientWidth - graphXpos - 20, yMax];
	for(var i=0;i<ticks.length;i+=2) {
		ctx.fillText(ticks[i+1], graphXpos + ticks[i], graphYpos - 5);
	}
	//ticksPositions
	ctx.fillStyle = "#c0c0c0";
	for(var i=0;i<ticks.length;i+=2) {
		ctx.fillRect(graphXpos + ticks[i], graphYpos, 1, 5);
	}
	//Axes
	ctx.fillRect(graphXpos - 5, graphYpos + 5, ctx.canvas.clientWidth - graphXpos - 10, 1);
	ctx.fillRect(graphXpos, graphYpos, 1, 30*xLabels.length + 10);

	//content
	ctx.fillStyle = color;
	for(var i=0;i<yData.length;i++)
		ctx.fillRect(graphXpos + 1, graphYpos + 10 + 30*i, yData[i] * yMultiply, 25);
}
