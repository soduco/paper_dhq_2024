library(tidyverse) # Tidyverse is a collection of R packages designed for data science
library(sf) # Handling spatial data
library(data.table)
library(spatstat)
library(osmdata) # extract Paris current limit and Notre-Dame Cathedral
library(gridExtra) # multiploting
library(latex2exp) # write as latex
library(classInt) # To create classes for choropleth maps
library(patchwork) # To combine plots
library(ggthemes) # To use ggplot2 colorblind-friendly color palettes
library(scales) # To rescale color gradients
library(colorspace) # To use diverging color palettes
library(concaveman) # To create concave hulls

source(file = "functions.R")

#### Data: importing, critics and reorganizing ####
###### 3 juridical boundaries of Paris #####
# before 1860:
admin_before_1860 <- st_read(dsn = "data-paris-delim/Vasserot_district/Vasserots_quartiers_v.shp") %>%
  st_union()

# after 1860:
admin_after_1860 <- st_read(dsn = "data-paris-delim/quartiers_paris_post_1860.shp") %>%
  st_union()

# current delineation:
osmdataparis <- getbb(place_name = "Paris") %>% 
  opq() %>% 
  add_osm_feature(key = "admin_level", value = 8) %>% # https://wiki.openstreetmap.org/wiki/FR:Key:admin_level
  osmdata_sf()

osmdataparis <- osmdataparis$osm_multipolygons[1,] %>%
  dplyr::select(osm_id, name) %>%
  st_transform(crs = 2154)

##### import selection of city directories years ####
seq_of_years <- c(seq(1800, 1914, 5), 1914)
# rearrange years (when no city directories): 
seq_of_years[5] <- 1822 # Bottin 1820: some bug in cardinalities of addresses due to page cross-references
# see: https://soduco.geohistoricaldata.org/public/images/seminaire2/2eJourneeSoDUCoBNF_01_Inventaire_annuaires_Cristofoli.pdf
seq_of_years[7] <- 1829 # no directory in 1830
seq_of_years[9] <- 1841 # in 1840 Cambon almagene (diff. collection), choice of Didot
seq_of_years[14] <- 1864 # no directory in 1865
seq_of_years[20] <- 1894 # no directory in 1895
seq_of_years[22] <- 1904 # very weird result of N for 1905
seq_of_years[23] <- 1909 # because DidotBottin and 1910 is Paris_Hachette

# extracting data from .gpkg
data_alphabetical_list <- st_read(dsn = "directories-ListNoms.gpkg", layer = "1800") %>%
  st_cast(x=., to="POINT") %>%
  st_transform(crs = 2154)

for (i in 2:length(seq_of_years)) {
  yearspec <- as.character(seq_of_years[i])
  data_reading <- st_read(dsn = "directories-ListNoms.gpkg", layer = yearspec) %>%
    st_cast(x=., to="POINT") %>%
    st_transform(crs = 2154)
  data_alphabetical_list <- data_alphabetical_list %>%
    bind_rows(data_reading)
}


# view series for each year
editors_years <- data_alphabetical_list %>%
  dplyr::select(source.publication_year, source.book) %>%
  st_drop_geometry() %>%
  unique()
editors_years

# one edition for one year (removing "duplicated" potential mentions of individuals)
data_alphabetical_list <- data_alphabetical_list %>%
  filter(source.book %ni% c('Bazar_1822', 'Deflandre_1829',
                            'Panckoucke_hab_Dulac_1835','Cambon_alm_1835','Cambon_almgene_1841', 'Bottin3_1855',
                            'Paris_adresses_1894', 'Paris_adresses_1900', 'Paris_Hachette_1904_ex2'))

##### data-driven critics: geocoding ####
geocoding <- data_alphabetical_list %>%
  mutate(is_empty = st_is_empty(x=.)) %>%
  dplyr::select(source.publication_year, is_empty, geocoding.response.name, 
                geocoding.response.number, address.number, address.name)

entries <- data_alphabetical_list %>%
  st_drop_geometry() %>%
  group_by(uuid, source.publication_year, source.book) %>%
  count()

df_synthetic_geolocations_stats <- entries %>%
  group_by(source.publication_year, source.book) %>%
  mutate(source.book = str_sub(source.book, end=-6)) %>%
  summarise(N.entries = n()) %>%
  left_join(y = geocoding %>%
              st_drop_geometry() %>%
              group_by(source.publication_year) %>%
              summarise(N.addresses = n()), by = 'source.publication_year') %>%
  left_join(y = geocoding %>%
              filter(is_empty == FALSE) %>%
              st_drop_geometry() %>%
              group_by(source.publication_year) %>%
              summarise(N.geoloc.addresses = n()), by = 'source.publication_year') %>%
  left_join(y = geocoding %>%
              unique() %>%
              st_drop_geometry() %>%
              group_by(source.publication_year) %>%
              summarise(N.distinct.addresses = n()), by = 'source.publication_year') %>%
  left_join(y = geocoding %>%
              unique() %>%
              filter(is_empty == FALSE) %>%
              st_drop_geometry() %>%
              group_by(source.publication_year) %>%
              summarise(N.geoloc.distinct.addresses = n()), by = 'source.publication_year') %>%
  mutate(addresses.per.entries = round(N.addresses/N.entries, 3), 
         geoloc.addresses = round(N.geoloc.addresses/N.addresses, 3),
         geoloc.distinct.addresses.per.distinct.addresses = round(N.geoloc.distinct.addresses/N.distinct.addresses, 3))

write_csv(x = df_synthetic_geolocations_stats, file = "fig/df_synthetic_geolocation_stats.csv")

rm(geocoding, entries)

##### distinct geolocated addresses data ####
# bounding around old delineation of Paris with 2.5km buffer
boundingboxparis <- st_bbox(obj = admin_after_1860 %>% # addin buffer to expand limits
                              st_buffer(dist = 2500)) %>% 
  st_as_sfc() %>% 
  st_as_sf()

#### removing geometries bugs out of Paris
data_alphabetical_list <- data_alphabetical_list %>% # data with geometry
  mutate(is_empty = st_is_empty(x=.)) %>%
  filter(is_empty == FALSE) %>%
  st_filter(x = ., y = boundingboxparis, .predicate = st_within) # inside 2.5 km buffer

#### selecting only unique locations: i.e. addresses
data_alphabetical_list <- data_alphabetical_list %>% # data with geometry
  dplyr::select(source.publication_year, source.book, source.collection) %>%
  group_by_all() %>%
  unique()


#### Density evolution: section 2 ####
#### Parameter of hexagons size ####
# exploring mean density for 3 dates and diverse hexagon size
# 1835 & 1864 & 1890
grid_general_size <- admin_after_1860 %>%
  st_buffer(dist = 1000)
plot(grid_general_size)

cellsize_seq <- seq(100, 1000, 50)

sf_list_grid <- list()
for (i in 1:length(cellsize_seq)) {
  sf_list_grid[[i]] <- st_make_grid(x = grid_general_size, cellsize = cellsize_seq[i], square = FALSE) %>%
    st_as_sf() %>%
    rename(geometry=x) %>%
    rowid_to_column()
}

# compute density for 1835, 1864 and 1890
two_dates_test <- data_alphabetical_list %>%
  filter(source.publication_year %in% c(1835, 1864, 1890)) %>%
  group_by(source.publication_year) %>%
  group_split()

two_dates_grid <- list()
for (i in 1:length(sf_list_grid)) {
  d1_count <- st_join(x = two_dates_test[[1]], y = sf_list_grid[[i]], join = st_within) %>%
    st_drop_geometry() %>%
    group_by(rowid) %>%
    summarise(n=n())
  
  two_dates_grid[[i]] <- sf_list_grid[[i]] %>%
    left_join(y = d1_count, by = "rowid") %>%
    mutate(year=1835, cellsize = cellsize_seq[i])
  
  d2_count <- st_join(x = two_dates_test[[2]], y = sf_list_grid[[i]], join = st_within) %>%
    st_drop_geometry() %>%
    group_by(rowid) %>%
    summarise(n=n())
  
  two_dates_grid[[i]] <- two_dates_grid[[i]] %>%
    bind_rows(sf_list_grid[[i]] %>%
                left_join(y = d2_count, by = "rowid") %>%
                mutate(year=1864, cellsize = cellsize_seq[i]))
  
  d2_count <- st_join(x = two_dates_test[[3]], y = sf_list_grid[[i]], join = st_within) %>%
    st_drop_geometry() %>%
    group_by(rowid) %>%
    summarise(n=n())
  
  two_dates_grid[[i]] <- two_dates_grid[[i]] %>%
    bind_rows(sf_list_grid[[i]] %>%
                left_join(y = d2_count, by = "rowid") %>%
                mutate(year=1890, cellsize = cellsize_seq[i]))
  
}


# plot for explaination
ggplot() +
  geom_sf(data = two_dates_grid[[5]], fill='grey95') +
  geom_sf(data=grid_general_size, alpha=0, linewidth=1) +
  ggspatial::annotation_scale(location = "bl",  width_hint = 0.2) +
  theme_bw() +
  theme(axis.text.x = element_blank(),
        axis.text.y = element_blank(),
        axis.ticks = element_blank(),
        axis.title.x = element_blank(), panel.grid = element_blank(),
        axis.title.y = element_blank(), legend.title = element_blank(), legend.position = 'bottom') +
  ggplot() +
  geom_sf(data = two_dates_grid[[11]], fill='grey95') +
  geom_sf(data=grid_general_size, alpha=0, linewidth=1) +
  ggspatial::annotation_scale(location = "bl",  width_hint = 0.2) +
  theme_bw() +
  theme(axis.text.x = element_blank(),
        axis.text.y = element_blank(),
        axis.ticks = element_blank(),
        axis.title.x = element_blank(), panel.grid = element_blank(),
        axis.title.y = element_blank(), legend.title = element_blank(), legend.position = 'bottom')


ggsave(filename = 'fig/example-hexa-grid-300-600-metres.pdf', width = 29.7, height = 21, units = 'cm', dpi = 300)

# binding list and plot results
two_dates_grid_bind <- rbindlist(l = two_dates_grid) %>% st_as_sf()

# ploting 
breaksp <- 10^(-10:10)
minor_breaksp <- rep(1:9, 21)*(10^rep(-10:10, each=9))

two_dates_grid_bind %>%
  filter(!is.na(n)) %>% # without NA
  st_drop_geometry() %>%
  group_by(year, cellsize) %>%
  summarise(mean = mean(n), et = sd(n)) %>%
  mutate(year=as.character(year)) %>%
  ggplot(mapping = aes(x=cellsize, group=year)) +
  geom_line(mapping = aes(y = mean, color=year)) +
  #geom_ribbon(aes(y = mean, ymin = mean-et, ymax=mean+et, fill= year), alpha=0.1) +
  ggthemes::scale_color_colorblind() +
  #ggthemes::scale_fill_colorblind() +
  theme_bw() +
  scale_x_continuous(name = 'hexagon size (in m.)', breaks = seq(100, 1000, 100)) +
  scale_y_log10(name='mean density', breaks=breaksp, minor_breaks=minor_breaksp) +
  theme(legend.position = c(0.8, 0.2), legend.background = element_rect(fill = 'white', size=0.3, color = 'grey30'))

ggsave(filename = 'fig/test-cellsize.pdf', width = 17, height = 15, units = 'cm', dpi = 300)

rm(two_dates_grid_bind)

#### Qualitative parameter: 400 m. (after iterative tests) ####
##### overview in 1822-1914 #####
## count points in hexagons for 1822-1914
hexagons_250 <- sf_list_grid[[7]] # 400 m grid
list_pt_years <- data_alphabetical_list %>%
  filter(source.publication_year > 1819) %>%
  group_by(source.publication_year) %>%
  group_split()

list_pt_years_count <- list()
for (i in 1:length(list_pt_years)) {
  list_pt_years_count[[i]] <- count_pt_in_hexagons(sf_list_of_year_points = list_pt_years[[i]], 
                                                   sf_hexagons_choice = hexagons_250) %>%
    mutate(year=list_pt_years[[i]]$source.publication_year[1])
}

list_pt_years_count <- rbindlist(list_pt_years_count) %>%
  st_as_sf()

#### New occupation in hexagons (appearing and disappearing)
vectors_by_years <- list_pt_years_count %>%
  filter(!is.na(n)) %>%
  st_drop_geometry() %>%
  group_by(year) %>%
  group_split()

vectors_by_years2 <- list()
for (i in 1:length(vectors_by_years)) {
  vectors_by_years2[[i]] <- vectors_by_years[[i]]$rowid
}

evolution_hexagons <- tibble()
for (i in 1:(length(vectors_by_years2)-1)) {
  disappear <- length(setdiff(x = vectors_by_years2[[i]], y = vectors_by_years2[[i+1]]))
  appear <- length(setdiff(x = vectors_by_years2[[i+1]], y = vectors_by_years2[[i]]))
  evolution_hexagons <- evolution_hexagons %>%
    bind_rows(tibble(appears = appear, disappears = disappear, 
                     t1 = vectors_by_years[[i]]$year[1], t2 = vectors_by_years[[i+1]]$year[1],
                     nhexat1 = length(vectors_by_years2[[i]]), nhexat2 = length(vectors_by_years2[[i+1]])))
}

# ploting
evolution_hexagons %>%
  mutate(appears=appears/nhexat2, disappears=disappears/nhexat1) %>%
  pivot_longer(cols = appears:disappears, names_to = 'dynamics', values_to = 'hexagons') %>%
  ggplot(mapping = aes(x=t2, y=hexagons, group=dynamics, color=dynamics)) +
  geom_line() +
  ggthemes::scale_color_fivethirtyeight(labels = unname(TeX(c("Appears: $N_{appears}/N_{t+1}$",
                                                              "Disappears: $N_{disappears}/N_{t}")))) +
  theme_bw() +
  theme(legend.position = c(0.8, 0.6), legend.background = element_rect(fill = 'white', size=0.3, color = 'grey30'),
        legend.title = element_blank()) +
  labs(x=TeX(r"($t+1$)"), y = element_blank(), subtitle = 'Dynamics of appearing and disappearing of 400 m. hexagons')

ggsave(filename = 'fig/400-appears_disappears.pdf', width = 17, height = 15, units = 'cm', dpi = 300)


#### Center-periphery evolution of density
# center is Notre-Dame de Paris (Cathedral)
center <- getbb(place_name = "Paris") %>% 
  opq() %>% 
  add_osm_feature(key = "addr:street", value = "Parvis Notre-Dame - Place Jean-Paul II") %>% # from osm
  osmdata_sf()

plot(center$osm_polygons)

center <- center$osm_polygons %>%
  dplyr::select(osm_id, name) %>%
  st_centroid() %>%
  st_transform(crs = 2154)

plot(hexagons_250$geometry)
plot(center$geometry, add = TRUE, col = "red")

# computing distance matrices with attributes of density
split_year_sf <- list_pt_years_count %>%
  mutate(n = if_else(is.na(n), 0, n)) %>% #N=23100
  group_by(year) %>%
  group_split()

distance_to_center <- tibble(geometry=st_sfc()) %>%
  st_as_sf(crs=2154)

for (i in 1:length(split_year_sf)) {
  no_na_sf <- split_year_sf[[i]] %>%
    st_centroid(x=.)
  no_na_ppp <- as.ppp(X = no_na_sf)
  center_ppp <- as.ppp(X = center)
  
  dist_matrix <- crossdist(X = no_na_ppp, Y = center_ppp)
  distance_to_center <- distance_to_center %>%
    bind_rows(split_year_sf[[i]] %>%
                bind_cols(dist_matrix %>% 
                            as_tibble() %>%
                            rename(distance=V1)))
}

nrow(distance_to_center) # 23100

# ploting
distance_to_center %>%
  st_drop_geometry() %>%
  filter(n!=0) %>%
  ggplot(mapping = aes(x=distance,y=n,group=year,color=year)) +
  geom_line(linewidth=0.07) +
  stat_smooth(se = FALSE, linewidth=0.8, method = 'loess', formula = 'y~x') +
  ggthemes::scale_color_gradient_tableau(palette = 'Orange') +
  theme_bw() +
  scale_x_log10(name='Distance to Notre-Dame de Paris (in m.)', breaks=breaksp, minor_breaks=minor_breaksp) +
  scale_y_log10(name='N geolocated adresses in hexagon', breaks=breaksp, minor_breaks=minor_breaksp) +
  theme(legend.position = c(0.15, 0.3), 
        legend.background = element_rect(fill = 'white', size=0.3, color = 'grey30'))

ggsave(filename = 'fig/400-dist-to-center-overview.pdf', width = 17, height = 15, units = 'cm', dpi = 300)
# 
# 
# # center is barycenter of init point pattern
# center2 <- data_alphabetical_list %>% 
#   filter(source.publication_year==1822) %>%
#   ungroup() %>%
#   summarise() %>%
#   st_centroid(x = .)
# 
# distance_to_center <- tibble(geometry=st_sfc()) %>%
#   st_as_sf(crs=2154)
# 
# for (i in 1:length(split_year_sf)) {
#   no_na_sf <- split_year_sf[[i]] %>%
#     st_centroid(x=.)
#   no_na_ppp <- as.ppp(X = no_na_sf)
#   center_ppp <- as.ppp(X = center2)
#   
#   dist_matrix <- crossdist(X = no_na_ppp, Y = center_ppp)
#   distance_to_center <- distance_to_center %>%
#     bind_rows(split_year_sf[[i]] %>%
#                 bind_cols(dist_matrix %>% 
#                             as_tibble() %>%
#                             rename(distance=V1)))
# }
# 
# # ploting
# distance_to_center %>%
#   st_drop_geometry() %>%
#   filter(n!=0) %>%
#   ggplot(mapping = aes(x=distance,y=n,group=year,color=year)) +
#   geom_line(linewidth=0.07) +
#   stat_smooth(se = FALSE, linewidth=0.8, method = 'loess', formula = 'y~x') +
#   ggthemes::scale_color_gradient_tableau(palette = 'Orange') +
#   theme_bw() +
#   scale_x_log10(name='Distance to barycenter of point pattern in 1825 (in m.)', 
#                 breaks=breaksp, minor_breaks=minor_breaksp) +
#   scale_y_log10(name='N geolocated adresses in hexagon', breaks=breaksp, minor_breaks=minor_breaksp) +
#   theme(legend.position = c(0.25, 0.4), 
#         legend.background = element_rect(fill = 'white', size=0.3, color = 'grey30'))
# 
# ggsave(filename = 'fig/fig_adresses/400-dist-to-center-overview2.pdf', width = 17, height = 15, units = 'cm', dpi = 300)

#### computing general density in 1822-1914
addresses_period <- data_alphabetical_list %>%
  dplyr::select(geom) %>%
  unique()

# count in hexagons
addresses_period <- count_pt_in_hexagons(sf_list_of_year_points = addresses_period, sf_hexagons_choice = hexagons_250) %>%
  filter(!is.na(n))

hist(addresses_period$n, nclass = 50)
classes <- classIntervals(var = addresses_period$n, style = "jenks", n = 9)

ggplot() +
  geom_sf(data = osmdataparis, color='grey70', linewidth = 0.2, alpha=0)+
  geom_sf(data = addresses_period, 
          mapping = aes(fill=cut(n, classes$brks)), alpha=0.9) +
  scale_fill_brewer(palette = "YlOrRd") +
  geom_sf(data = admin_after_1860, linewidth = 0.2, alpha=0, color='grey30') +
  ggspatial::annotation_scale(location = "bl",  width_hint = 0.2) +
  theme_bw() +
  theme(axis.text.x = element_blank(),
        axis.text.y = element_blank(),
        axis.ticks = element_blank(),
        axis.title.x = element_blank(), panel.grid = element_blank(),
        axis.title.y = element_blank(), legend.title = element_blank(), legend.position = 'bottom')

ggsave(filename = 'fig/400-adresses_density.pdf', 
       width = 29.7, height = 21, units = 'cm', dpi = 300)

##### slopes during 1822-1914: dynamics of urban density #####
#### Computing general slope for period 1882 to 1914
slope_sf_hexagons <- f_slope_hexagons(sf_hexagons = distance_to_center) %>%
  filter(slope_period != 0)

ggplot() +
  geom_sf(data = osmdataparis, fill='grey90', linewidth = 0.2) +
  geom_sf(data = slope_sf_hexagons %>%
            dplyr::select(geometry, slope_period) %>%
            rename(slope=slope_period) %>%
            unique(), 
          mapping = aes(fill=slope), linewidth=0.05) +
  scale_fill_fermenter(palette = "Reds", direction = 1) +
  geom_sf(data = admin_after_1860, linewidth = 0.2, alpha=0)+
  ggspatial::annotation_scale(location = "bl",  width_hint = 0.2) +
  theme_bw() +
  theme(axis.text.x = element_blank(),
        axis.text.y = element_blank(),
        axis.ticks = element_blank(),
        axis.title.x = element_blank(), panel.grid = element_blank(),
        axis.title.y = element_blank(), legend.position = 'bottom')

ggsave(filename = 'fig/400-slope_1820-1914.pdf', width = 17, height = 15, units = 'cm', dpi = 300)


#### cartography of deviation to general slope for each hexagon for all periods
slope_sf_periods <- slope_sf_hexagons %>%
  filter(slope_t != 0) %>%
  mutate(begin = as.numeric(str_sub(time_period, start=1, end=4)), ending = as.numeric(str_sub(time_period, start=6, end=9))) %>%
  mutate(DtN = (slope_t-slope_period)/abs(x = slope_period),
         Dt_minus_mean=(slope_t-slope_period), Dt_normalized = slope_t/(ending-begin))

classes <- classIntervals(var = slope_sf_periods$DtN, style = "box", iqr_mult = 3) # 
# with 0 as big breaks
classes$brks[4] <- 0

ggplot() +
  geom_sf(data = slope_sf_periods, 
          mapping = aes(fill=cut(DtN, classes$brks, include.lowest = TRUE))) +
  scale_fill_brewer(palette = "PiYG", direction = -1) +
  geom_sf(data = osmdataparis, color='grey70', linewidth = 0.2, alpha=0)+
  geom_sf(data = admin_after_1860, linewidth = 0.2, alpha=0)+
  geom_sf(data = admin_before_1860, linewidth = 0.2, alpha=0)+
  ggspatial::annotation_scale(location = "bl",  width_hint = 0.2) +
  facet_wrap(~time_period) +
  theme_bw() +
  theme(axis.text.x = element_blank(),
        axis.text.y = element_blank(),
        axis.ticks = element_blank(),
        axis.title.x = element_blank(), panel.grid = element_blank(),
        axis.title.y = element_blank(), legend.title = element_blank(), legend.position = 'bottom')

ggsave(filename = 'fig/400-cartography_of_deviation_slopes_by_full_period.pdf', 
       width = 29.7, height = 21, units = 'cm', dpi = 300)


#### Cartography of local slope in time of an hexagon to local slopes of all hexagons (center-scale)
# equivalent to space-normalized slope per period
slope_time_space <- slope_sf_hexagons %>%
  filter(slope_t != 0) %>%
  group_by(time_period) %>%
  mutate(meanslope = mean(slope_t), sdslope = sd(slope_t)) %>%
  ungroup() %>%
  mutate(center_scaled_slope = (slope_t-meanslope)/sdslope)

hist(slope_time_space$center_scaled_slope, nclass = 100)

classes <- classIntervals(var = slope_time_space$center_scaled_slope, style = "box", iqr_mult = 3) # 
# with 0 as big breaks
classes$brks[4] <- 0


ggplot() +
  geom_sf(data = slope_time_space, 
          mapping = aes(fill=cut(center_scaled_slope, classes$brks, include.lowest = FALSE))) +
  scale_fill_brewer(palette = "PiYG", direction = -1) +
  geom_sf(data = osmdataparis, color='grey70', linewidth = 0.2, alpha=0)+
  geom_sf(data = admin_after_1860, linewidth = 0.2, alpha=0)+
  geom_sf(data = admin_before_1860, linewidth = 0.2, alpha=0)+
  ggspatial::annotation_scale(location = "bl",  width_hint = 0.2) +
  facet_wrap(~time_period) +
  theme_bw() +
  theme(axis.text.x = element_blank(),
        axis.text.y = element_blank(),
        axis.ticks = element_blank(),
        axis.title.x = element_blank(), panel.grid = element_blank(),
        axis.title.y = element_blank(), legend.title = element_blank(), legend.position = 'bottom')

ggsave(filename = 'fig/400-cartography_of_slopes_deviation_in_space.pdf', 
       width = 29.7, height = 21, units = 'cm', dpi = 300)

#### Cartography of absolute slope t to evaluate if center-scale negative results are diminution or relative augmentation
hist(x = slope_sf_periods$Dt_normalized, nclass = 100)
summary(slope_sf_periods$Dt_normalized)

ggplot() +
  geom_sf(data = slope_sf_periods, 
          mapping = aes(fill=Dt_normalized)) +
  scale_fill_binned(breaks = c(-6, -1, 0, 0.41, 10), type = 'viridis') +
  geom_sf(data = osmdataparis, color='grey70', linewidth = 0.2, alpha=0)+
  geom_sf(data = admin_after_1860, linewidth = 0.2, alpha=0)+
  geom_sf(data = admin_before_1860, linewidth = 0.2, alpha=0)+
  ggspatial::annotation_scale(location = "bl",  width_hint = 0.2) +
  facet_wrap(~time_period) +
  theme_bw() +
  theme(axis.text.x = element_blank(),
        axis.text.y = element_blank(),
        axis.ticks = element_blank(),
        axis.title.x = element_blank(), panel.grid = element_blank(),
        axis.title.y = element_blank(), legend.title = element_blank(), legend.position = 'bottom')

ggsave(filename = 'fig/400-cartography_of_slopes_t.pdf', 
       width = 29.7, height = 21, units = 'cm', dpi = 300)


#### Gazetteer analyses: section 3 ####
##### gazetteer cartography #####
gazetteer <- st_read(dsn="data-geocoder-gazetteer/atlas_jacoubet_1836_housenumbers.csv") %>%
  select(lon, lat) %>%
  st_as_sf(coords = c("lon", "lat"), crs = 4326)  %>%
  st_transform(crs = 2154) %>%
  mutate(gazetteer = '1836') %>% 
  mutate(layer = 'housenumbers')


gazetteer <- gazetteer %>% bind_rows(
  st_read(dsn="data-geocoder-gazetteer/atlas_jacoubet_1836_streets_centerpoints.csv") %>%
    select(lon, lat) %>%
    st_as_sf(coords = c("lon", "lat"), crs = 4326)  %>%
    st_transform(crs = 2154) %>%
    mutate(gazetteer = '1836') %>% 
    mutate(layer = 'streets')
)

gazetteer <- gazetteer %>% bind_rows(
  st_read(dsn="data-geocoder-gazetteer/atlas_municipal_1888_housenumbers.csv") %>%
    select(lon, lat) %>%
    st_as_sf(coords = c("lon", "lat"), crs = 4326)  %>%
    st_transform(crs = 2154) %>%
    mutate(gazetteer = '1888') %>% 
    mutate(layer = 'housenumbers')
)

gazetteer <- gazetteer %>% bind_rows(
  st_read(dsn="data-geocoder-gazetteer/atlas_municipal_1888_streets_centerpoints.csv") %>%
    select(lon, lat) %>%
    st_as_sf(coords = c("lon", "lat"), crs = 4326)  %>%
    st_transform(crs = 2154) %>%
    mutate(gazetteer = '1888') %>% 
    mutate(layer = 'streets')
)


gazetteer <- gazetteer %>% bind_rows(
  st_read(dsn="data-geocoder-gazetteer/atlas_andriveaugoujon_1849_streets_centerpoints.csv") %>%
    select(lon, lat) %>%
    st_as_sf(coords = c("lon", "lat"), crs = 4326)  %>%
    st_transform(crs = 2154) %>%
    mutate(gazetteer = '1849') %>% 
    mutate(layer = 'streets')
)

gazetteer <- gazetteer %>% bind_rows(
  st_read(dsn="data-geocoder-gazetteer/atlas_verniquet_1791_streets_centerpoints.csv") %>%
    select(lon, lat) %>%
    st_as_sf(coords = c("lon", "lat"), crs = 4326)  %>%
    st_transform(crs = 2154) %>%
    mutate(gazetteer = '1791') %>% 
    mutate(layer = 'streets')
)


plt_1 <- ggplot() +
  geom_sf(data = gazetteer, aes(color = layer), size = .02, shape = 4, show.legend = "point") +
  theme_minimal() +
  theme(legend.position = "none") +
  facet_wrap(~gazetteer, ncol = 4) +    
  theme(panel.grid.major = element_line(color = "gray", size = 0.05),
        panel.grid.minor = element_line(color = "gray", size = 0.01),
        axis.text.x = element_text(angle = 60, hjust = 1, size = 6),
        axis.text.y = element_text(hjust = 1, size = 6),
        legend.position = "top") +
  labs(title = element_blank(), x = element_blank(), y = element_blank())


ggsave("fig/gazetteers.pdf", plt_1, width = 20, units = "cm")

##### concave hull cartography #####
map_layers <- st_read(dsn = "data-paris-delim/map_shapes.gpkg", layer = "jacoubet_1836") %>% 
  mutate(gazetteer = "1836")

map_layers <- map_layers %>% 
  bind_rows(
    st_read(dsn = "data-paris-delim/map_shapes.gpkg", layer = "municipal_1888") %>% 
      mutate(gazetteer = "1888")
  )

gazetteer <- st_read(dsn="data-geocoder-gazetteer/atlas_jacoubet_1836_housenumbers.csv") %>%
  select(lon, lat) %>%
  st_as_sf(coords = c("lon", "lat"), crs = 4326)  %>%
  st_transform(crs = 2154) %>%
  mutate(gazetteer = '1836')


gazetteer <- gazetteer %>% bind_rows(
  st_read(dsn="data-geocoder-gazetteer/atlas_municipal_1888_housenumbers.csv") %>%
    select(lon, lat) %>%
    st_as_sf(coords = c("lon", "lat"), crs = 4326)  %>%
    st_transform(crs = 2154) %>%
    mutate(gazetteer = '1888')
)

concave_hulls <- gazetteer %>% 
  filter(gazetteer == "1836") %>%
  concaveman(concavity = 0.5) %>%
  mutate(gazetteer = "1836")  %>%
  bind_rows(
    gazetteer %>% 
      filter(gazetteer == "1888") %>%
      concaveman(concavity = 0.5) %>%
      mutate(gazetteer = "1888")
  )


plt <- ggplot() + 
  geom_sf(data = map_layers %>% filter(layer == "mapped_area"), fill = "#707070AA", show.legend = "line") +
  geom_sf(data = map_layers %>% filter(layer == "cityboundaries"), color = "black", fill="transparent", show.legend = "line") +
  geom_sf(data = concave_hulls, fill = "black", linewidth = 0) +
  facet_wrap(~ gazetteer, ncol=2) + 
  scale_colour_manual(name="Scenarios:") +
  labs(x = "Longitude", y = "Latitude") +
  theme_minimal()

ggsave("fig/mapped_area.pdf", plt, width = 40, units = "cm")

##### directory VS gazetteer density analysis #####

# Load the shapefile of Paris districts after 1860
paris_districts_after_1860 <- st_read(dsn = "data-paris-delim/quartiers_paris_post_1860.shp")

# Create an approximate but realistic shape of Paris
paris_area_after_1860 <- st_union(paris_districts_after_1860)

# Load the geocoder gazetteers for approx. 1836 (Jacoubet's map) and 1888 (Atlas municipal), retain only the columns lat and lon
gazetteers <- read.csv("data-geocoder-gazetteer/atlas_jacoubet_1836_housenumbers.csv")  %>%
  select(lon, lat) %>%
  st_as_sf(coords = c("lon", "lat"), crs = 4326)  %>%
  st_transform(crs = 2154) %>%
  mutate(gazetteer = 'jacoubet_1836')

gazetteers <- gazetteers %>% bind_rows(
  read.csv("data-geocoder-gazetteer/atlas_municipal_1888_housenumbers.csv")  %>%
    select(lon, lat) %>%
    st_as_sf(coords = c("lon", "lat"), crs = 4326) %>%
    st_transform(crs = 2154) %>%
    mutate(gazetteer = 'municipal_1888')
)


# Add the street points
gazetteers <- read.csv("data-geocoder-gazetteer/atlas_jacoubet_1836_streets_centerpoints.csv")  %>%
  select(lon, lat) %>%
  st_as_sf(coords = c("lon", "lat"), crs = 4326)  %>%
  st_transform(crs = 2154) %>%
  mutate(gazetteer = 'jacoubet_1836') %>%
  bind_rows(gazetteers)

gazetteers <- read.csv("data-geocoder-gazetteer/atlas_municipal_1888_streets_centerpoints.csv")  %>%
  select(lon, lat) %>%
  st_as_sf(coords = c("lon", "lat"), crs = 4326)  %>%
  st_transform(crs = 2154) %>%
  mutate(gazetteer = 'municipal_1888') %>%
  bind_rows(gazetteers)

# Load the directories for the dates closest to 1836 and 1888 :
# - 1835
# - 1890
directories <- st_read(dsn = "directories-ListNoms.gpkg", layer = "1835") %>%
  st_cast(x=., to="POINT") %>%
  # Keep only unique points, ie. addresses
  group_by_all() %>%
  unique() %>%
  st_transform(crs = 2154) %>%
  mutate(directory = 1835)



directories <- directories %>% bind_rows(
  st_read(dsn = "directories-ListNoms.gpkg", layer = "1890") %>%
    st_cast(x=., to="POINT") %>%
    st_transform(crs = 2154) %>%
    mutate(directory = 1890))


directories_geolocations <- directories %>% 
  # remove empty geometries
  filter(!st_is_empty(.)) %>%
  # Drop rows where geocoding.response.source is not in {atlas_jacoubet_1836, atlas_municipal_1888}
  filter(geocoding.response.source %in% c("atlas_jacoubet_1836", "atlas_municipal_1888")) %>%
  # In a directory, if a geometry is duplicated, keep only one
  distinct(directory, geom)


# Creation of a hexagonal grid covering the approximate area of Paris
GRID_RESOLUTION <- 400
hexgrid <- st_make_grid(x = paris_area_after_1860, cellsize = GRID_RESOLUTION, square = FALSE) %>%
  st_as_sf() %>%
  dplyr::rename(geometry=x) %>%
  rowid_to_column()

# MAIN ANALYSIS

###
# Relative density of directories points to both the
# Jacoubet's map and Atlas municipal gazetteers

# Count the number of directories points in each hexagon of the grid
# Cells with no points are filled with 0
directories_count <- st_join(hexgrid, directories_geolocations) %>%
  group_by(rowid, directory) %>%
  dplyr::summarise(directories_points = n(), .groups = "drop") %>%
  complete(nesting(rowid, geometry), directory, fill = list(directories_points = 0), explicit = FALSE) %>%
  drop_na(directory) %>%
  st_as_sf()

# Count the number of gazetteers points in each hexagon of the grid
# Cells with no points are filled with 0
gazetteers_count <- st_join(hexgrid, gazetteers) %>%
  group_by(rowid, gazetteer) %>%
  dplyr::summarise(gazetteers_points = n(), .groups = "drop") %>%
  complete(nesting(rowid, geometry), gazetteer, fill = list(gazetteers_points = 0), explicit = FALSE) %>%
  drop_na(gazetteer) %>%
  st_as_sf()


# Compure the relative density
# of gazetteers points to directories points in each hexagon
ratio_df <- left_join(directories_count, st_drop_geometry(gazetteers_count), by = "rowid") %>%
  # Filter out cells with no points in both the gazetteer and directory
  filter(gazetteers_points > 0 & directories_points > 0) %>%
  # Compute the ratio. 
  # We add 1 to the numerator and denominator to avoid division by 0
  mutate(ratio = (gazetteers_points + 1) / (directories_points + 1))

# Create a plot for each directory (1835 and 1890) and for each gazetteer (jacoubet_1836 and municipal_1888)
plots <- list()
plots_addresses <- list()

for (directory in sort(unique(ratio_df$directory))) {
  for (gazetteer in sort(unique(ratio_df$gazetteer))) {
    # Extract the rows where the directory and gazetteer are the current values
    local <- ratio_df %>% 
      filter(directory == !!directory, gazetteer == !!gazetteer)
    
    # Ratio values are clamped between -10 and 10
    local$ratio <- pmax(-10, pmin(10, local$ratio))
    
    
    plot <- ggplot(local) +
      geom_sf(data = paris_area_after_1860, fill = "lightgrey", color = "black") +
      geom_sf(aes(fill = ratio)) +
      scale_fill_gradientn(colours = colorspace::diverging_hcl(50, palette = "Green-Orange"), 
                           values = rescale(c(min(local$ratio),1,max(local$ratio))),
                           guide = guide_colorbar(direction='vertical'), 
                           limits=c(min(local$ratio),max(local$ratio)),
                           name="Density ratio") +
      theme(legend.position = "left", axis.text.x = element_blank(), axis.text.y = element_blank(), axis.ticks.x= element_blank(), axis.ticks.y= element_blank())
    plots[[paste(directory, gazetteer)]] <- plot
    
    
    plot <- ggplot(local  %>% pivot_longer(cols = c("gazetteers_points", "directories_points"), names_to = "type", values_to = "count")) +
      geom_sf(data = paris_area_after_1860, fill = "lightgrey", color = "black") +
      geom_sf(aes(fill = count), color = alpha("black", 0)) +
      scale_fill_viridis_c(name="Density", option="cividis", guide = guide_colorbar(barwidth = 0.5, barheight = 5, direction='vertical')) +
      theme(legend.title=element_text(size=10), legend.text=element_text(size=10), legend.position = "right", axis.text.x = element_blank(), axis.text.y = element_blank(), axis.ticks.x = element_blank(), axis.ticks.y = element_blank(), legend.margin=margin(0,0,0,0), legend.box.margin=margin(0,0,0,-50)) +
      facet_wrap(~type, ncol = 1, labeller = as_labeller(c("directories_points" = "Geolocated addresses", "gazetteers_points" = "Gazetteer adddesses")))
    plots_addresses[[paste(directory, gazetteer)]] <- plot
    
  }
}

layout <- "
AABBCCDD
EEFFGGHH
"

final_plot <- (
  plots[[1]] + plots_addresses[[1]] +
    plots[[2]] + plots_addresses[[2]] +
    plots[[3]] + plots_addresses[[3]] +
    plots[[4]] + plots_addresses[[4]] +
    plot_layout(design = layout, widths = c(1, 1, 1, 1), heights = c(1, 1, 1, 1))
  + plot_annotation(tag_levels = list(c('a', '','b','','c','','d')),
                    caption = 'Disclaimer: WIP, this figure is not final and is subject to change.')
)


# Export the final plot
ggsave("fig/densityratio-1835-1890-jacoubet-municipal.pdf", final_plot, dpi = 400, width=40, units="cm")

#### geocoding assessment in fringes from Didot 1845: section 3 ####
# load data
data_didot <- st_read(dsn = "data-1845-didot-outskirts/1845_didot_etudes_marges.gpkg")

# compute diverse tibble of evaluation
first_tibble <- data_didot %>%
  select(geocoding.query.layer, geocoding.response.layer, geocoding.response.source, IntraExtra) %>%
  st_drop_geometry() %>%
  group_by_all() %>%
  count()

write.csv(x = first_tibble, file = "fig/didot_first_tibble.csv")

second_tibble <- data_didot %>%
  select(address.number, address.name, geocoding.query.layer, geocoding.response.layer, geocoding.response.source, IntraExtra) %>%
  st_drop_geometry() %>%
  group_by_all() %>%
  unique() %>%
  ungroup() %>%
  group_by(geocoding.query.layer, geocoding.response.layer, geocoding.response.source, IntraExtra) %>%
  count()

write.csv(x = second_tibble, file = "fig/didot_second_tibble.csv")

third_tibble <- data_didot %>%
  select(geocoding.query.layer, geocoding.response.layer, geocoding.response.source, IntraExtra) %>%
  mutate(is_empty = st_is_empty(x=.)) %>%
  filter(is_empty==FALSE) %>%
  unique() %>%
  st_drop_geometry() %>%
  select(-is_empty) %>%
  group_by_all() %>%
  count()

write.csv(x = third_tibble, file = "fig/didot_third_tibble.csv")

# cartography of discrepancies
data_didot <- data_didot %>%
  mutate(error = case_when(
    ERR == 0 ~ 'good geocoding', ERR == 1 ~ 'bad geocoding', ERR == 2 ~ 'approximate geocoding',
    ERR == 3 ~ 'incorect street name in directory', ERR == 4 ~ 'incorect parsing from NER', ERR == 5 ~ 'street not included in gazetteer', 
    ERR == 6 ~ 'other cases', TRUE ~ 'no systematic evaluation'
  ))

ntypes <- data_didot %>%
  st_drop_geometry() %>%
  group_by(error) %>%
  count()

data_didot <- data_didot %>%
  left_join(y = ntypes, by = 'error') %>%
  mutate(error = paste0(error, ' (', n, ')'))

# spatial data bounding
fortifications_thiers <- st_read(dsn = "data-paris-delim/Thiers_enclosure/rcap-enceinte-de-thiers-1841-a-1844-limites-liees-au-systeme-de-bastions.shp") %>%
  st_transform(crs = 2154)

#### removing geometries bugs out of Paris
data_didot <- data_didot %>% # data with geometry
  st_filter(x = ., y = boundingboxparis, .predicate = st_within) %>% # inside 2.5 km buffer
  mutate(opacity = if_else(error == 'no systematic evaluation (59671)', "0.2", "1"))

# cartography
ggplot() +
  geom_sf(data=admin_before_1860, alpha=0, linewidth=0.2) +
  geom_sf(data = fortifications_thiers, color = 'darkgrey', linewidth=0.4) +
  geom_sf(data = data_didot %>% filter(error != 'other cases (1)'), 
          aes(color=error, alpha=opacity, size=opacity, shape=error)) +
  scale_shape_manual(values = 15:21) + # full shape
  scale_alpha_manual(values = c("0.2"=0.35, "1"=1), guide=NULL) +
  scale_size_manual(values = c("0.2"=0.2, "1"=1.7), guide=NULL) +
  ggthemes::scale_color_colorblind() +
  ggspatial::annotation_scale(location = "bl",  width_hint = 0.2) +
  theme_bw() +
  theme(axis.text.x = element_blank(),
        axis.text.y = element_blank(),
        axis.ticks = element_blank(),
        axis.title.x = element_blank(), panel.grid = element_blank(), legend.text = element_text(size = 7),
        legend.margin = margin(t = 0, r = 0, b = 0, l = 0, unit = 'pt'),
        axis.title.y = element_blank(), legend.title = element_blank()) +
  theme(legend.position = 'bottom') +
  NULL

ggsave(filename = 'fig/didot-1845-discrepancies.pdf', width = 19, height = 14, units = 'cm', dpi = 300)
ggsave(filename = 'fig/final-fig/didot-1845-discrepancies.png', width = 19, height = 14, units = 'cm', dpi = 300)




