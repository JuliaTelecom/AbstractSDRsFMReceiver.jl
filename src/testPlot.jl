using PlotlyJS



layout = Layout(;title=" Spectrum ",
				xaxis_title=" Frequency  ",
				yaxis_title=" Power ",
				xaxis_showgrid=true, yaxis_showgrid=true,
				#xaxis_range = [0,3000],
				#legend_y=1.15, legend_x=0.7, 
				)
N = 100;
x = 0:N-1;
y = randn(N);
pl1	  = scatter(; x,y, name=" ");
plt = plot(pl1,layout)
