library(rnaturalearth)
library(sf)
library(cartography)


# Data download

## Natural Earth
# ne_download(scale = 50, type = "ocean", category = "physical", destdir = "data", 
#             load = FALSE, returnclass = 'sf')
# ne_download(scale = 50, type = "countries", category = "cultural", 
#             destdir = "data", load = FALSE, returnclass = 'sf')

# Dataset OIM 

## Download

# for (i in 2014:2018){
#   download.file(url = paste0("http://missingmigrants.iom.int/global-figures/",i,"/csv"), 
#                 destfile = paste0("data/mdm",i,".csv"))
# }

## Data import

mdm <- read.csv("data/mdm2014.csv", stringsAsFactors = F)
mdm <- rbind(mdm,read.csv("data/mdm2015.csv", stringsAsFactors = F))
mdm <- rbind(mdm,read.csv("data/mdm2016.csv", stringsAsFactors = F))
mdm <- rbind(mdm,read.csv("data/mdm2017.csv", stringsAsFactors = F))
mdm <- rbind(mdm,read.csv("data/mdm2018.csv", stringsAsFactors = F))

# data.frame -> sf
latlon <- matrix(as.numeric(unlist(strsplit(mdm$Location.Coordinates, 
                                            split = ", "))), ncol = 2, byrow = T)
colnames(latlon) <- c("lat", 'lon')
mdm <- cbind(mdm, latlon)

mdm <- st_as_sf(mdm, coords = c("lon", "lat"), crs = 4326)

mdm <- mdm[mdm$Region%in%"Mediterranean",]
mdm <- st_transform(mdm, 3395)

# Ocean
ctry <- st_read("data/ne_50m_admin_0_countries.shp")
ctry <- st_transform(ctry, 3395)

ocean <- st_read(dsn = "data/ne_50m_ocean.shp")
ocean <- st_transform(ocean, 3395 )
bbocean <- st_bbox(c(xmin = -982800, xmax = 4070000, 
                     ymin = 3450000, ymax = 5710000), 
                   crs = st_crs(ocean))

ocean <- st_crop(ocean, bbocean)
ocean <- st_cast(ocean, to = "POLYGON")
ocean <- ocean[10, ]
p2 <- rbind(c(3030089,4992571), 
            c(3030089,5927043), 
            c(4155959,5927043),
            c(4155959,4992571), 
            c(3030089,4992571))
pol <-st_polygon(list(p2))
pol <- st_sfc(pol, crs = st_crs(ocean))
ocean <- st_difference(ocean, pol)

sizes <- getFigDim(x = ocean, width = 800,mar = c(0,0,1.2,0), res = 100)
sizes <- c(1200, 560)
xlim = c(-570000, 3900000)
ylim = c(3500000, 5650000)


lay <- function(title = ""){
  # CARTOGRAPHIC LAYOUT
  layoutLayer(frame = TRUE, tabtitle = TRUE, scale = 200, north = F, 
              author = "T. Giraud & N. Lambert, 2018", title = title,
              source = "Sources: IOM, 2018")
  p <- c(-648841, 4467573)
  text(p[1], 4507864, "Gibraltar", adj = c(0.5,0),  col="#70747a",cex=0.7)
  arrows(p[1], p[2], p[1], p[2]-100000, code = 2, length = 0.1,  col="#70747a")
  text(1667817, 5026113, "ITALY", adj = c(0.5,0), col="#70747a",cex=0.8)
  text(-467143.1, 4800787, "SPAIN", adj = c(0.5,0), col="#70747a",cex=0.8)
  text(3419723, 4654326, "TURKEY", adj = c(0.5,0), col="#70747a",cex=0.8)
  text(3391557, 3460100, "EGYPT", adj = c(0.5,0), col="#70747a",cex=0.8)
  text(1065071, 4305071, "TUNISIA", adj = c(0.5,0), col="#70747a",cex=0.8)
  text(-427711.1, 3910751, "MOROCCO", adj = c(0.5,0), col="#70747a",cex=0.8)
  text(434159.2, 4091012, "ALGERIA", adj = c(0.5,0), col="#70747a",cex=0.8)
  text( 1481923, 3505165, "LIBYA", adj = c(0.5,0), col="#70747a",cex=0.8)
  text( 2400125, 4806420, "GREECE", adj = c(0.5,0), col="#70747a",cex=0.8)
}


png("output/rawPlot.png", width = sizes[1], height = sizes[2], res = 100)
par(mar = c(0,0,1.2,0))
plot(ocean$geometry,col = "lightblue", border = NA,
     xlim = xlim, ylim = ylim)
propSymbolsLayer(mdm, var  = "Total.Dead.and.Missing", 
                 col = "red", fixmax = 750,inches = 0.3,
                 border = "white", lwd = .8, legend.pos = "n")
legendCirclesSymbols(pos = "topright", 
                     title.txt = "Number of\ndead and missing", 
                     var = c(750,300,100,10), inches = .3, col = "red", 
                     style = "e")
lay("Dead & Missing Migrants, 2014-2018")
dev.off()












# Décomposition temporelle
par(mar = c(0,0,1.2,0), mfrow = c(3,2))
for (i in 2014:2018){
  plot(ocean$geometry,col = "lightblue", border = NA,
       xlim = xlim, ylim = ylim)
  propSymbolsLayer(mdm[mdm$Reported.Year==i,], 
                   var  = "Total.Dead.and.Missing", col = "red", inches = 0.3,
                   border = "white", lwd = .6, legend.pos = "n", fixmax = 750)
  box()
  # lay(i)
}



# Compter les points dans une grille (représentation par points ou par carreaux)
# Create a regular grid (adm bbox)
grid <- st_make_grid(x = ocean, cellsize = 100000, what = "polygons")
. <- st_intersects(grid, ocean)
grid <- grid[sapply(X = ., FUN = length)>0]
grid <- st_sf(idgrid = 1:length(grid), grid)
. <- st_intersection(mdm, grid)
griddf <- aggregate(.$Total.Dead.and.Missing, by = list(idgrid = .$idgrid), sum)
grid <- merge(grid, griddf, by = "idgrid", all.x = TRUE)

png("output/gridPlot.png", width = sizes[1], height = sizes[2], res = 100)
par(mar = c(0,0,1.2,0))
bks <- getBreaks(grid[grid$x>0,"x", drop = T], nclass = 10, method = "geom")
cols <- carto.pal("red.pal", 10)
plot(ocean$geometry,col = "lightblue", border = NA,
     xlim = xlim, ylim = ylim)
choroLayer(x = grid[grid$x>0,], var = "x", legend.pos = NA,
           border = NA, add=T, colNA = NA, 
           col =cols, breaks = bks) 
legendChoro(pos = "topright", title.txt = "Density of\ndead and missing\n(per 100 km2)",
            breaks = bks, col = cols, cex = 0.6, values.rnd = 0, nodata = F)
plot(grid[order(grid$x, decreasing = T),"geometry"][1,], add=T, lwd = 2)
p <- c(-648841, 4467573)
text(1240000, 3735000, "24.5\ndead or missing\nper km2", adj = c(0.5 ,1),  col="#70747a",cex=0.7)
arrows(1254749, 3737898, 1307223, 3804683, code = 2, length = 0.1,  col="#70747a")
lay("Dead & Missing Migrants, 2014-2018")
dev.off()






# Aggregation spatiale (avec CAH sur les XY)
mdm$x <- st_coordinates(mdm)[,1]
mdm$y <- st_coordinates(mdm)[,2]
# CAH aggregation 
nbclass<-8
height<- NULL
#height<- 1000000000000
method<-"single" #ward.D, ward.D2, complete, single
data <- as.data.frame(mdm)
data <- data[data$Total.Dead.and.Missing>0,]
colnames(data)
data$id <- data$Web.ID
xy <- data.frame(id=data$id,x=data$x,y=data$y)
rownames(xy) <- xy$id
d <- dist(xy, method = "euclidean", diag = FALSE, upper = FALSE, p = 2)
cah <- hclust(d, method = method, members = NULL)
# dev.off()
# plot(cah, labels = NULL, hang = 0, axes = TRUE, frame.plot = FALSE,
#      ann = TRUE, main = "Cluster Dendrogram", sub = NULL, xlab = NULL, ylab = "Height")
classif <- cutree(cah, h = height, k = nbclass)
classif <- as.data.frame(classif)
classif <- data.frame(id=row.names(classif),class=classif$classif)
data <- data.frame(data, classif[match(data[,"id"],classif[,"id"]),])
nb <- length(unique(classif$class))
datax <- by(data,data$class, function(x) weighted.mean(x$x, x$Total.Dead.and.Missing),simplify = TRUE)
datay <- by(data,data$class, function(x) weighted.mean(x$y, x$Total.Dead.and.Missing),simplify = TRUE)
data2 <- aggregate(data$Total.Dead.and.Missing, by = list(id = data$class), sum, simplify = TRUE)
datax<-as.vector(datax)
datay<-as.vector(datay)
oim_cah <- data.frame(id=data2$id,x=datax,y=datay,death_aggr=data2$x)
oim_cah_sf <- st_as_sf(oim_cah, coords = c("x", "y"), crs = st_crs(mdm))

png("output/CAH.png", width = sizes[1], height = sizes[2], res = 100)
par(mar = c(0,0,1.2,0))
plot(ocean$geometry,col = "lightblue", border = NA,
     xlim = xlim, ylim = ylim)
propSymbolsLayer(x = oim_cah_sf, var = "death_aggr", 
                 symbols = "circle", col =  "red",fixmax = 750,
                 legend.pos = "n", border = "white",
                 legend.title.txt = "death_aggr",
                 legend.style = "c",inches = 0.3)
labelLayer(x = oim_cah_sf[-5,], txt = "death_aggr", cex = c(2, 1, 1, 0.7, 0.7, 0.7, 0.7), 
           col = "white")
labtext <- data.frame(lab = c("Central\nMediterranea", "Western\nMediterranea", 
                              "Aegean Sea", "Egypt Coast", "Cyprus", "Crete"), 
                      x = c(1544634.2, -426723.9, 2988275.7, 3073046.2, 3809219.6, 2796077.6), 
                      y = c(4258000, 4008000, 4802000, 3600000, 4167000, 4050000)) 
text(x = labtext$x, labtext$y, labels =labtext$lab, cex =  c(1.6, 1, 1, 0.7, 0.7, 0.7), font = 2)

layoutLayer(frame = TRUE, tabtitle = TRUE, scale = 200, north = F, 
            author = "T. Giraud & N. Lambert, 2018", 
            title = "Dead & Missing Migrants, 2014-2018",
            source = "Sources: IOM, 2018")
dev.off()








# Lissage 
library("SpatialPosition")
res <- 25000
span <- 75000
unk <- CreateGrid(w = as(ocean, 'Spatial'), res = res)
stew <- stewart(knownpts = as(mdm, 'Spatial'), varname = "Total.Dead.and.Missing", 
        typefct = "exponential", beta = 2, unknownpts = unk, span = span)
ras <- rasterStewart(stew)

# red liss
contour <- rasterToContourPoly(r = ras, 
                               breaks = c(0,25,50,100,175,250,500,
                                          1000,2000,3000,4000))
iso_pop <- st_as_sf(contour[c(-9, -10),])
iso_pop
# order iso surfaces
iso_pop <- iso_pop[order(iso_pop$center),]
# color palette à la viridis
pal <-carto.pal("red.pal", 10)[3:10]
png("output/smooth1.png", width = sizes[1], height = sizes[2], res = 100)
par(mar = c(0,0,1.2,0))
plot(ocean$geometry,col = "lightblue", border = NA,
     xlim = xlim, ylim = ylim)
for(i in 1:nrow(iso_pop)){
  p <- st_geometry(iso_pop[i,])
  # plot light contour polygons with a Nort-West shift
  plot(p + c(-5000, 5000), add=T, border = "#ffffff90",col = "#ffffff90")
  # plot dark contour polygons with a South-East shift
  plot(p + c(7000, -7000),  col = "#00000099", add=T, border = "#00000099")
  # plot colored contour polygons in place
  plot(p, col = pal[i], border = "NA", add=T)
}
plot(ocean$geometry,col = NA, border = "#ffffff80", lwd = 1,
     xlim = xlim, ylim = ylim, add=T)
labtext <- data.frame(lab = c("Central\nMediterranea", "Western\nMediterranea",
                              "Aegean Sea", "Egypt Coast", "Cyprus", "Crete", "Lybia"), 
                      x = c(1504634.2, -426723.9, 2978275.7, 
                            3073046.2, 3809219.6, 2796077.6, 1528228), 
                      y = c(4703372, 3908000, 5000000, 3480000, 
                            4155000, 4000000,3551342 )) 
text(x = labtext$x, labtext$y, labels =labtext$lab, 
     cex = c(1, 1, 1, 1, 0.7, 0.7), font = 2)
bks <- c("Low", "", "Medium", "", "High", "","Very High", "", "")
legendChoro(pos = "topright", breaks = bks, 
            title.txt = "Level of Mortality\n(dead and missing)",
            col = pal, nodata = F, values.rnd = -1, cex = 0.7)
layoutLayer(frame = TRUE, tabtitle = TRUE, scale = 200, north = F, 
            author = "T. Giraud & N. Lambert, 2018", 
            title ="Dead & Missing Migrants, 2014-2018",
            source = "Sources: IOM, 2018")
dev.off()






# Blue liss
contour <- rasterToContourPoly(r = ras, 
                               breaks = c(0,5,10,25,50,100,175,250,500,
                                          1000,2000,3000,4000))
iso_pop <- st_as_sf(contour)
iso_pop <- iso_pop[-nrow(iso_pop),]
# order iso surfaces
iso_pop <- iso_pop[order(iso_pop$center),]
# color palette à la viridis

carto.pal("blue.pal", 20)[18]
pal <-carto.pal("blue.pal", nrow(iso_pop))
png("output/smooth2.png", width = sizes[1], height = sizes[2], res = 100)
par(mar = c(0,0,1.2,0))
plot(ocean$geometry,col = "#DCF0F8", border = NA,
     xlim = xlim, ylim = ylim)
for(i in 1:nrow(iso_pop)){
  p <- st_geometry(iso_pop[i,])
  # plot light contour polygons with a Nort-West shift
  plot(p - c(-5000, 5000), add=T, border = "#ffffff90",col = "#ffffff90")
  # plot dark contour polygons with a South-East shift
  plot(p - c(7000, -7000),  col = "#14405A", add=T, border = "#14405A")
  # plot colored contour polygons in place
  plot(p, col = pal[i], border = "NA", add=T)
}
plot(ctry$geometry, col = "#ffffff", border = "#ffffff", lwd = 1,
     xlim = xlim, ylim = ylim, add=T)
bks <- c("Low", "","", "Medium", "","", "High", "","","Very High", "", "")
legendChoro(pos = "topright", breaks = bks, 
            title.txt = "Level of Mortality\n(dead and missing)",
            col = pal, nodata = F, values.rnd = -1, cex = 0.7)
lay("Dead & Missing Migrants, 2014-2018")
dev.off()


################### Dorling

library(cartogram)
w <- 1 - (mdm$y / max(mdm$y))
mdmdor <- cartogram_dorling(x = st_jitter(mdm), 
                            weight = "Total.Dead.and.Missing",k = .8)

png("output/dorling.png", width = sizes[1], height = sizes[2], res = 100)
par(mar = c(0,0,1.2,0))
plot(ocean$geometry,col = "lightblue", border = NA,
     xlim = xlim, ylim = ylim)
plot(mdmdor$geometry, add=T,  border = "white", col = "red", lwd = .8)
lay("Dead & Missing Migrants, 2014-2018")
dev.off()






################################################################################
# library(plot3D)
# r <- ras
# r <- aggregate(x = r, fact  = c(2,2), method = "bilinear")
# p3 <- as.matrix(r)
# perspbox(z=p3, asp = 1, d = 5, scale = TRUE, bty="b2", expand=0.3, main="test",
#          phi=20, theta=80, zlim=c(0,max(p3)))
# persp3D(z = p3, add=T,  border="grey20", col = "#ffffff")
# library(rayshader)
# library(magrittr)
# elmat = matrix(raster::extract(localtif,raster::extent(localtif),buffer=1000),
#                nrow=ncol(localtif),ncol=nrow(localtif))
# r <- t(as.matrix(ras))
# elmat <- r/75
# elmat %>%
#   sphere_shade(texture = "imhof3") %>%
#   add_water(detect_water(elmat), color="bw") %>%
#   add_shadow(ray_shade(elmat)) %>%
#   add_shadow(ambient_shade(elmat)) %>%
#   plot_3d(elmat) %>%
#   save_png(elmat,"toto.png")
# # Zoom + dorling
# # zoom + fonction de la distance
# # MAp position
# bbmed <- st_bbox(mdm)
# par(mar=c(0,0,0,0))
# plot(st_geometry(ocean), col = "lightblue", border = NA, 
#      xlim = bbmed[c(1,3)], ylim = bbmed[c(2,4)])
# plot(mdm$geometry, add=T, pch = 21, bg = "red", col = "white", 
#      lwd = .8, cex = 0.75)
# 
# 
# # MAp Quantities
# plot(st_geometry(ocean), col = "lightblue", border = NA, 
#      xlim = bbmed[c(1,3)], ylim = bbmed[c(2,4)])
# propSymbolsLayer(mdm, var  = "Total.Dead.and.Missing", col = "red", inches = 0.5,
#                  border = "white", lwd = .6)
# 
# 
# 
# # Map zone
# library(cartogram)
# par(mar=c(0,0,0,0), mfrow = c(1,2))
# bbzone <- st_bbox(c(xmin = 1049943, ymin = 3462796, 
#                     xmax =2187520,  ymax = 4759943), crs = st_crs(mdm))
# mdmzone <- st_crop(mdm, bbzone)
# mdmzone <- mdmzone[!is.na(mdmzone$Number.Dead),]
# 
# plot(st_geometry(ocean), col = "lightblue", border = NA, 
#      xlim = bbzone[c(1,3)], ylim = bbzone[c(2,4)])
# propSymbolsLayer(mdmzone, var  = "Total.Dead.and.Missing", col = "red", 
#                  border = "white", lwd = .6, inches = 0.25)
# 
# w <- 1 - (mdmzone$Total.Dead.and.Missing / max(mdmzone$Total.Dead.and.Missing))
# mdmdor <- cartogram_dorling(x = st_jitter(mdmzone), 
#                             weight = "Total.Dead.and.Missing", k = 2)
# plot(st_geometry(ocean), col = "lightblue", border = NA, 
#      xlim = bbzone[c(1,3)], ylim = bbzone[c(2,4)])
# plot(mdmdor$geometry, add=T,  border = "white", col = "red", lwd = .8)
# typoLayer(mdmdor, var = "Reported.Year", col = carto.pal("wine.pal", 7)[3:7],add=T, border ="grey", lwd = 0.5)
# 
# 
# # 
# # library(SpatialPosition)
# # x <- as(mdm,'Spatial')
# # xx <- quickStewart(spdf = x, df = x@data, var = "Number.Dead", typefct = "exponential", span = 75000, beta = 3)
# # par(mar=c(0,0,0,0))
# # plot(st_geometry(ocean), col = "lightblue", border = NA, 
# #      xlim = bbmed[c(1,3)], ylim = bbmed[c(2,4)])
# # choroLayer(spdf = xx, var = "center", nclass = 8, add=T)
# 
# 
# ## Across time
# dev.off()
# par(mar=c(0,0,0,0), mfrow = c(2,3))
# for (i in 2014:2018){
#   plot(st_geometry(ocean), col = "lightblue", border = NA, 
#        xlim = bbzone[c(1,3)], ylim = bbzone[c(2,4)])
#   propSymbolsLayer(st_jitter(mdmzone[mdmzone$Reported.Year==i, ]), var  = "Number.Dead", 
#                    col = "red", fixmax = 100,legend.pos = "n",
#                    border = "white", lwd = .6, inches = 0.2)
#   mtext(text = i, side = 3, line = -2)
# }
# 








