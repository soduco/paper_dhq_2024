## Paper DHQ 2024
Repository for the material of our paper submitted in [special issue](https://www.c2dh.uni.lu/news/cfp-data-science-and-history-practicing-and-theorizing-data-driven-inquiries-past) of DHQ.

#### Important deadlines
- [ ] 1st of March, 2024: first version of paper (5000/8000 words)
- [ ] 15 May, 2024: final version to DHQ

## Repository organisation of data-analysis
```
.
├── data-1845-didot-outskirts
│   ├── 1845_didot_etudes_marges.gpkg
│   └── 1845_didot_etudes_marges.qml
├── data-geocoder-gazetteer
│   ├── atlas_andriveaugoujon_1849_streets_centerpoints.csv
│   ├── atlas_jacoubet_1836_housenumbers.csv
│   ├── atlas_jacoubet_1836_streets_centerpoints.csv
│   ├── atlas_municipal_1888_housenumbers.csv
│   ├── atlas_municipal_1888_streets_centerpoints.csv
│   └── atlas_verniquet_1791_streets_centerpoints.csv
├── data-paris-delim
│   ├── Thiers_enclosure/...
│   ├── Vasserot_district/...
│   ├── map_shapes.gpkg
│   └── quartiers_paris_post_1860.shp
├── fig/...
├── 1_data-download.R
├── 2_data-analysis.R
├── directories-ListNoms.gpkg
├── functions.R
├── grateful-refs.bib
└── README.md
```

## Data information
### City directories

The "directories-ListNoms.gpkg" dataset (version 4 on Nakala) was created in SoDUCo ANR Project and is open on Nakala platform [doi: 10.34847/nkl.98eem49t.v4](https://nakala.fr/10.34847/nkl.98eem49t.v4), Etalab Open License 2.0. See documentation and presentations on Nakala platform for precise information. The initial data (6.75 Go) must be downloaded to reproduce data analyses (see _1_data-download.R_ file).

### Historical geocoder gazetteer

The gazetteer used in geocoding process is in _data-geocoder-gazetteer_ file.

### Geocoding evaluation of Didot 1845 directory

Data of the manual evaluation of the geocoding in the fringes of the dense urban area of Paris from the directory of Didot in 1845 is contained in _data-1845-didot-outskirts_ file.

### Administrative delineations of Paris during the 19th century and Thiers wall

Two data-sets compose the administrative delineations of Paris:

- 1790-1860: A.-L. Bethe, « Dataset: Vasserot “Quartiers” (Neighbourhoods) (1790-1860) - Licence ODbL 1.0 », Analyse Diachronique de l’espace Urbain Parisien: Approche Geomatique, 2015, [Online]. Available at: http://purl.stanford.edu/ry227xq8127. Data is in _data-paris-delim_ file.

- 1860-1919: district data (named in _data/init_datasets_ "quartiers_paris_post_1860") was created in SoDUCo ANR Project and are open on Nakala platform [doi: 10.34847/nkl.a57506s3](https://doi.org/10.34847/nkl.a57506s3). See documentation in .pdf format on Nakala platform for precise information and licence to know how to use the data. Data is in _data-paris-delim_ file.

Thiers wall:
- 1841-1849: R&CAP. « Enceinte de Thiers (1841 à 1844), Limites liées au système de bastions », Licence ODbL 1.0, 2021, [Online]. Available at: http://www.fabriquenumeriquedupasse.fr/explore/dataset/rcap-enceinte-de-thiers-1841-a-1844-limites-liees-au-systeme-de-bastions.


## R code information

### R session
```{r}
devtools::session_info()
─ Session info ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
 setting  value
 version  R version 4.2.0 (2022-04-22)
 os       macOS Big Sur 11.6.5
 system   x86_64, darwin17.0
 ui       RStudio
 language (EN)
 collate  en_US.UTF-8
 ctype    en_US.UTF-8
 tz       Europe/Paris
 date     2024-03-02
 rstudio  2023.09.1+494 Desert Sunflower (desktop)
 pandoc   3.1.1 @ /Applications/RStudio.app/Contents/Resources/app/quarto/bin/tools/ (via rmarkdown)
```

### R packages
See grateful-report and grateful-bib in _data-analysis_.

```{r}
devtools::session_info()

─ Packages ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
 package          * version date (UTC) lib source
 abind              1.4-5   2016-07-21 [1] CRAN (R 4.2.0)
 bit                4.0.5   2022-11-15 [1] CRAN (R 4.2.0)
 bit64              4.0.5   2020-08-30 [1] CRAN (R 4.2.0)
 bslib              0.5.0   2023-06-09 [1] CRAN (R 4.2.0)
 cachem             1.0.8   2023-05-01 [1] CRAN (R 4.2.0)
 callr              3.7.3   2022-11-02 [1] CRAN (R 4.2.0)
 class              7.3-22  2023-05-03 [1] CRAN (R 4.2.0)
 classInt         * 0.4-9   2023-02-28 [1] CRAN (R 4.2.0)
 cli                3.6.1   2023-03-23 [1] CRAN (R 4.2.0)
 colorspace       * 2.1-0   2023-01-23 [1] CRAN (R 4.2.0)
 concaveman       * 1.1.0   2020-05-11 [1] CRAN (R 4.2.0)
 crayon             1.5.2   2022-09-29 [1] CRAN (R 4.2.0)
 curl               5.1.0   2023-10-02 [1] CRAN (R 4.2.0)
 data.table       * 1.14.8  2023-02-17 [1] CRAN (R 4.2.0)
 DBI                1.1.3   2022-06-18 [1] CRAN (R 4.2.0)
 deldir             1.0-9   2023-05-17 [1] CRAN (R 4.2.0)
 devtools         * 2.4.5   2022-10-11 [1] CRAN (R 4.2.0)
 digest             0.6.33  2023-07-07 [1] CRAN (R 4.2.0)
 dplyr            * 1.1.2   2023-04-20 [1] CRAN (R 4.2.0)
 e1071              1.7-13  2023-02-01 [1] CRAN (R 4.2.0)
 ellipsis           0.3.2   2021-04-29 [1] CRAN (R 4.2.0)
 evaluate           0.23    2023-11-01 [1] CRAN (R 4.2.0)
 fansi              1.0.5   2023-10-08 [1] CRAN (R 4.2.0)
 farver             2.1.1   2022-07-06 [1] CRAN (R 4.2.0)
 fastmap            1.1.1   2023-02-24 [1] CRAN (R 4.2.0)
 forcats          * 1.0.0   2023-01-29 [1] CRAN (R 4.2.0)
 fs                 1.6.3   2023-07-20 [1] CRAN (R 4.2.0)
 generics           0.1.3   2022-07-05 [1] CRAN (R 4.2.0)
 ggdark             0.2.1   2019-01-11 [1] CRAN (R 4.2.0)
 ggplot2          * 3.4.2   2023-04-03 [1] CRAN (R 4.2.0)
 ggspatial          1.1.8   2023-04-13 [1] CRAN (R 4.2.0)
 ggthemes         * 4.2.4   2021-01-20 [1] CRAN (R 4.2.0)
 glue               1.6.2   2022-02-24 [1] CRAN (R 4.2.0)
 goftest            1.2-3   2021-10-07 [1] CRAN (R 4.2.0)
 grateful           0.2.4   2023-10-22 [1] CRAN (R 4.2.0)
 gridExtra        * 2.3     2017-09-09 [1] CRAN (R 4.2.0)
 gtable             0.3.3   2023-03-21 [1] CRAN (R 4.2.0)
 hms                1.1.3   2023-03-21 [1] CRAN (R 4.2.0)
 htmltools          0.5.6.1 2023-10-06 [1] CRAN (R 4.2.0)
 htmlwidgets        1.6.2   2023-03-17 [1] CRAN (R 4.2.0)
 httpuv             1.6.11  2023-05-11 [1] CRAN (R 4.2.0)
 httr2              1.0.0   2023-11-14 [1] CRAN (R 4.2.0)
 jquerylib          0.1.4   2021-04-26 [1] CRAN (R 4.2.0)
 jsonlite           1.8.7   2023-06-29 [1] CRAN (R 4.2.0)
 KernSmooth         2.23-21 2023-05-03 [1] CRAN (R 4.2.0)
 knitr              1.45    2023-10-30 [1] CRAN (R 4.2.0)
 labeling           0.4.2   2020-10-20 [1] CRAN (R 4.2.0)
 later              1.3.1   2023-05-02 [1] CRAN (R 4.2.0)
 latex2exp        * 0.9.6   2022-11-28 [1] CRAN (R 4.2.0)
 lattice            0.21-8  2023-04-05 [1] CRAN (R 4.2.0)
 lifecycle          1.0.4   2023-11-07 [1] CRAN (R 4.2.0)
 lubridate        * 1.9.2   2023-02-10 [1] CRAN (R 4.2.0)
 magrittr           2.0.3   2022-03-30 [1] CRAN (R 4.2.0)
 Matrix             1.5-4.1 2023-05-18 [1] CRAN (R 4.2.0)
 memoise            2.0.1   2021-11-26 [1] CRAN (R 4.2.0)
 mgcv               1.8-42  2023-03-02 [1] CRAN (R 4.2.0)
 mime               0.12    2021-09-28 [1] CRAN (R 4.2.0)
 miniUI             0.1.1.1 2018-05-18 [1] CRAN (R 4.2.0)
 munsell            0.5.0   2018-06-12 [1] CRAN (R 4.2.0)
 nlme             * 3.1-162 2023-01-31 [1] CRAN (R 4.2.0)
 osmdata          * 0.2.5   2023-08-14 [1] CRAN (R 4.2.0)
 patchwork        * 1.1.2   2022-08-19 [1] CRAN (R 4.2.0)
 pillar             1.9.0   2023-03-22 [1] CRAN (R 4.2.0)
 pkgbuild           1.4.2   2023-06-26 [1] CRAN (R 4.2.0)
 pkgconfig          2.0.3   2019-09-22 [1] CRAN (R 4.2.0)
 pkgload            1.3.3   2023-09-22 [1] CRAN (R 4.2.0)
 polyclip           1.10-4  2022-10-20 [1] CRAN (R 4.2.0)
 prettyunits        1.2.0   2023-09-24 [1] CRAN (R 4.2.0)
 processx           3.8.2   2023-06-30 [1] CRAN (R 4.2.0)
 profvis            0.3.8   2023-05-02 [1] CRAN (R 4.2.0)
 promises           1.2.1   2023-08-10 [1] CRAN (R 4.2.0)
 proxy              0.4-27  2022-06-09 [1] CRAN (R 4.2.0)
 ps                 1.7.5   2023-04-18 [1] CRAN (R 4.2.0)
 purrr            * 1.0.2   2023-08-10 [1] CRAN (R 4.2.0)
 R6                 2.5.1   2021-08-19 [1] CRAN (R 4.2.0)
 ragg               1.2.6   2023-10-10 [1] CRAN (R 4.2.0)
 rappdirs           0.3.3   2021-01-31 [1] CRAN (R 4.2.0)
 RColorBrewer       1.1-3   2022-04-03 [1] CRAN (R 4.2.0)
 Rcpp               1.0.11  2023-07-06 [1] CRAN (R 4.2.0)
 readr            * 2.1.4   2023-02-10 [1] CRAN (R 4.2.0)
 remotes            2.4.2.1 2023-07-18 [1] CRAN (R 4.2.0)
 renv               1.0.5   2024-02-29 [1] CRAN (R 4.2.0)
 rlang              1.1.1   2023-04-28 [1] CRAN (R 4.2.0)
 rmarkdown          2.25    2023-09-18 [1] CRAN (R 4.2.0)
 rpart            * 4.1.19  2022-10-21 [1] CRAN (R 4.2.0)
 rstudioapi         0.15.0  2023-07-07 [1] CRAN (R 4.2.0)
 s2                 1.1.4   2023-05-17 [1] CRAN (R 4.2.0)
 sass               0.4.7   2023-07-15 [1] CRAN (R 4.2.0)
 scales           * 1.2.1   2022-08-20 [1] CRAN (R 4.2.0)
 sessioninfo        1.2.2   2021-12-06 [1] CRAN (R 4.2.0)
 sf               * 1.0-13  2023-05-24 [1] CRAN (R 4.2.0)
 shiny              1.8.0   2023-11-17 [1] CRAN (R 4.2.0)
 spatstat         * 3.0-6   2023-05-17 [1] CRAN (R 4.2.0)
 spatstat.data    * 3.0-1   2023-03-12 [1] CRAN (R 4.2.0)
 spatstat.explore * 3.2-1   2023-05-13 [1] CRAN (R 4.2.0)
 spatstat.geom    * 3.2-1   2023-05-09 [1] CRAN (R 4.2.0)
 spatstat.linnet  * 3.1-1   2023-05-15 [1] CRAN (R 4.2.0)
 spatstat.model   * 3.2-4   2023-05-15 [1] CRAN (R 4.2.0)
 spatstat.random  * 3.1-5   2023-05-11 [1] CRAN (R 4.2.0)
 spatstat.sparse    3.0-2   2023-06-25 [1] CRAN (R 4.2.0)
 spatstat.utils     3.0-3   2023-05-09 [1] CRAN (R 4.2.0)
 stringi            1.7.12  2023-01-11 [1] CRAN (R 4.2.0)
 stringr          * 1.5.1   2023-11-14 [1] CRAN (R 4.2.0)
 systemfonts        1.0.5   2023-10-09 [1] CRAN (R 4.2.0)
 tensor             1.5     2012-05-05 [1] CRAN (R 4.2.0)
 textshaping        0.3.7   2023-10-09 [1] CRAN (R 4.2.0)
 tibble           * 3.2.1   2023-03-20 [1] CRAN (R 4.2.0)
 tidyr            * 1.3.0   2023-01-24 [1] CRAN (R 4.2.0)
 tidyselect         1.2.0   2022-10-10 [1] CRAN (R 4.2.0)
 tidyverse        * 2.0.0   2023-02-22 [1] CRAN (R 4.2.0)
 timechange         0.2.0   2023-01-11 [1] CRAN (R 4.2.0)
 tzdb               0.4.0   2023-05-12 [1] CRAN (R 4.2.0)
 units              0.8-2   2023-04-27 [1] CRAN (R 4.2.0)
 urlchecker         1.0.1   2021-11-30 [1] CRAN (R 4.2.0)
 usethis          * 2.2.2   2023-07-06 [1] CRAN (R 4.2.0)
 utf8               1.2.3   2023-01-31 [1] CRAN (R 4.2.0)
 V8                 4.3.0   2023-04-08 [1] CRAN (R 4.2.0)
 vctrs              0.6.4   2023-10-12 [1] CRAN (R 4.2.0)
 viridisLite        0.4.2   2023-05-02 [1] CRAN (R 4.2.0)
 vroom              1.6.3   2023-04-28 [1] CRAN (R 4.2.0)
 withr              2.5.2   2023-10-30 [1] CRAN (R 4.2.0)
 wk                 0.7.3   2023-05-06 [1] CRAN (R 4.2.0)
 xfun               0.40    2023-08-09 [1] CRAN (R 4.2.0)
 xml2               1.3.5   2023-07-06 [1] CRAN (R 4.2.0)
 xtable             1.8-4   2019-04-21 [1] CRAN (R 4.2.0)
 yaml               2.3.7   2023-01-23 [1] CRAN (R 4.2.0)

```
