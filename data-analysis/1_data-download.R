# data from Nakala plateform
# doi: 10.34847/nkl.98eem49t, version 4
options(timeout=10000)

# directories: alphabetical order
download.file(url = "https://api.nakala.fr/data/10.34847/nkl.98eem49t.v4/f443e5e02bffd124f4a78867bc2b2d094ec3ec87", 
              destfile = "directories-ListNoms.gpkg.zip")

unzip(zipfile = "directories-ListNoms.gpkg.zip", files = "directories-ListNoms.gpkg")

# directories: professional order
# download.file(url = "https://api.nakala.fr/data/10.34847/nkl.98eem49t.v4/73bd526d3b2851530b2c6edfd3c6433b1e1a1d27", 
#            destfile = "data-download/directories-ListProfs.gpkg.zip")

# unzip(zipfile = "data-download/directories-ListProfs.gpkg.zip", files = "directories-ListProfs.gpkg")
