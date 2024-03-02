# KDE diff between 2 dates
#' @param  t first date
#' @param t2 second date
kde_diff <- function(kde_data, t, t2, nkde2d){
  # Calculate the common x and y range for 2 dates datasets
  sft <- kde_data |> filter(source.publication_year == t)
  sft2 <- kde_data |> filter(source.publication_year == t2)
  
  xrng <- range(c(sft$x, sft2$x))
  yrng <- range(c(sft$y, sft2$y))
  
  # Calculate the 2d density estimate over the common range
  dt <- kde2d(sft$x, sft$y, lims=c(xrng, yrng), n=nkde2d)
  dt2 <- kde2d(sft2$x, sft2$y, lims=c(xrng, yrng), n=nkde2d)
  
  # Confirm that the grid points for each density estimate are identical
  print(identical(dt$x, dt2$x))
  print(identical(dt$y, dt2$y))
  
  # Calculate the difference between the 2d density estimates
  diff_2dates <- dt
  diff_2dates$z <- dt2$z-dt$z
  
  ## Melt data into long format
  rownames(diff_2dates$z) <- diff_2dates$x
  colnames(diff_2dates$z) <- diff_2dates$y
  
  # Now melt it to long format
  diff_2datesmelt <- melt(diff_2dates$z, id.var=rownames(diff_2dates))
  names(diff_2datesmelt) <- c("x","y","z")
  
  return(diff_2datesmelt)
}

# ni as inverse of select in
'%ni%' <- Negate('%in%')

# count points in a spatial grid
count_pt_in_hexagons <- function(sf_list_of_year_points, sf_hexagons_choice) {
  count_in_hexa <- st_join(x = sf_list_of_year_points, y = sf_hexagons_choice, join = st_within) %>%
    st_drop_geometry() %>%
    group_by(rowid) %>%
    summarise(n=n())
  
  outputcount <- sf_hexagons_choice %>%
    left_join(y = count_in_hexa, by = "rowid")
  return(outputcount)
}

# slope of n in hexagons
f_slope_hexagons <- function(sf_hexagons){
  general_slope <- sf_hexagons %>%
    st_drop_geometry() %>%
    filter(year %in% c(min(year), max(year))) %>%
    group_by(rowid) %>%
    mutate(slope_period = (n-lag(n))/(max(year)-min(year))) %>%
    filter(year != min(year)) %>%
    dplyr::select(rowid, slope_period)
  
  specific_slope_time <- sf_hexagons %>%
    arrange(rowid,year) %>%
    group_by(rowid) %>%
    mutate(slope_t = (n-lag(n))/(year - lag(year))) %>% 
    mutate(time_period = paste0(lag(year), '-', year)) %>%
    filter(!is.na(slope_t)) %>% 
    dplyr::select(time_period, rowid, slope_t, distance)
  
  slope <- specific_slope_time %>%
    left_join(y = general_slope, by = 'rowid')
  return(slope)
}

