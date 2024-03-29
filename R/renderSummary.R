#' Render Summary
#'
#' Renders the the Rmd summary for a variable in a csv that has a region and a
#' time column.
#'
#' @param outFileNameGlue \code{character(1)}. File name (without extension) of the
#'   output document to be created. Supports glue syntax. The following variables
#'   are available: \code{variableName}, \code{databaseName}.
#' @param outDirPath \code{character(1)}. The directory where the output document
#'   and intermediary files are created.
#' @param outFormat \code{character(1)}, not case-sensitive. \code{"html"},
#'   \code{"pdf"}, or \code{"rmd"}.
#' @param envir \code{environment}. The environment in which the code chunks are
#'   to be evaluated. See the argument of the same name in
#'   \code{\link[rmarkdown:render]{rmarkdown::render()}}. Set this to
#'   \code{globalenv()} and \code{sections} to \code{NULL} to load an preprocess
#'   data in your global environment during development.
#' @param quiet \code{logical(1)}. Suppress printing during rendering?
#' @param debug \code{logical(1)}. Should the debug Rmd be rendered instead of
#'   the main one?
#' @param nBatches \code{integer(1)}. Number of batches to split the rendering.
#' @param batchIndex \code{integer(1)}. Index of the batch to be rendered.
#' @param ... YAML parameters, see below.
#' @return The value returned by
#'   \code{\link[rmarkdown:render]{rmarkdown::render()}}.
#' @section YAML Parameters:
#' \describe{
#'   \item{\code{dataFilePath}}{
#'     \code{character(1)}.
#'     Path to a csv file.}
#'   \item{\code{variableName}}{
#'     \code{character(n)}.
#'     Vector of names of the columns in the csv file \code{dataFilePath} to be shown. There will be one output file per name.}
#'   \item{\code{regionName}}{
#'     \code{character(1)}.
#'     Default: \code{"GID_1"}.
#'     The name of the region column in the csv file \code{dataFilePath}.}
#'   \item{\code{regionNameDelim}}{
#'     \code{character(1)}.
#'     Default: \code{"."}.
#'     Delimiter to split the \code{regionName} into country and subRegionId.}
#'   \item{\code{regionNamePartNames}}{
#'     \code{character(2)}.
#'     Default: \code{c("country", "subRegionId")}.
#'     Names of the parts of the \code{regionName} after split by \code{regionNameDelim}.}
#'   \item{\code{countryName}}{
#'     \code{character(1)}.
#'     Default: \code{"country"}.
#'     Name of the country column in the csv file \code{dataFilePath}.}
#'   \item{\code{timeName}}{
#'     \code{character(1)}.
#'     Default: \code{"year"}.
#'     The name of the time column in the csv file \code{dataFilePath}.}
#'   \item{\code{timeRange}}{
#'     \code{numeric(2)} or \code{NULL}.
#'     Default: \code{c(1950, 2050)}.
#'     The maximum time range to be shown.}
#'   \item{\code{shapeRegionFilePath}}{
#'     \code{character(1)}.
#'     Path to a shapefile with region geometries.}
#'   \item{\code{shapeRegionLayer}}{
#'     \code{NULL} or \code{character(1)}.
#'     Default: \code{NULL}.
#'     The name of the layer in the shapefile \code{shapeRegionFilePath} with region geometries.}
#'   \item{\code{shapeRegionName}}{
#'     \code{character(1)}.
#'     Default: \code{"GID_1"}.
#'     The name of the region column in the shapefile \code{shapeRegionFilePath}.}
#'   \item{\code{shapeCountryFilePath}}{
#'     \code{character(1)}.
#'     Path to a shapefile with country geometries.}
#'   \item{\code{shapeCountryLayer}}{
#'     \code{NULL} or \code{character(1)}.
#'     Default: \code{NULL}.
#'     The name of the layer in the shapefile \code{shapeCountryFilePath} with country geometries.}
#'   \item{\code{shapeCountryName}}{
#'     \code{character(1)}.
#'     Default: \code{"GID_1"}.
#'     The name of the country column in the shapefile \code{shapeCountryFilePath}.}
#'   \item{\code{regionRegex}}{
#'     \code{character(1)} or \code{NULL}.
#'     Default: \code{NULL}.
#'     A regular expression to filter the regions.}
#'   \item{\code{countryRegex}}{
#'     \code{character(1)} or \code{NULL}.
#'     Default: \code{NULL}.
#'     A regular expression to filter the countries.}
#'   \item{\code{aggregateFunctions}}{
#'     \code{list(...)}.
#'     Default: \code{list(mean = \(x) mean(x, na.rm=TRUE), sd = \(x) sd(x, na.rm=TRUE))}.
#'     A named list of functions to aggregate values from a group. The first one (typically mean or sum) also marks the no-aggregation statistic.}
#'   \item{\code{transformations}}{
#'     \code{list(...)}.
#'     Default: \code{list(mean = c("identity", "log10"), sd = "identity")}.
#'     A named list of character vectors with the same names as \code{aggregateFunctions}. The transformations applied to the scales of the (aggregated) variable for plotting.}
#'   \item{\code{createMaps}}{
#'     \code{logical(1)}.
#'     Default: \code{TRUE}.
#'     Should maps be created? This might take some minutes.}
#'   \item{\code{figWidth, figHeight}}{
#'     \code{numeric(1)}.
#'     Default: \code{10} and \code{6}, respectively.
#'     Size of plots in inches.}
#'   \item{\code{warning}}{
#'     \code{logical(1)}.
#'     Default: \code{FALSE}.
#'     Show warnings in output?}
#' }
#' @author Christof Schoetz
#' @export
renderSummary <- function(
  outDirPath = getwd(),
  outFileNameGlue = "summary_{databaseName}_{variableName}",
  outFormat = "HTML",
  envir = new.env(),
  quiet = FALSE,
  debug = FALSE,
  nBatches = 1,
  batchIndex = 1,
  ...
) {
  # Set yaml parameters and convert relative to absolute paths.
  yamlParams <- list(...)
  paths <- str_subset(names(yamlParams), "Path$")
  for (path in paths) {
    yamlParams[[path]] <- normalizePath(yamlParams[[path]])
  }

  if (debug) {
    rmdSourceFilePath <- system.file("markdown/summary_debug.Rmd", package = "cerExploreData")
  } else {
    rmdSourceFilePath <- system.file("markdown/summary.Rmd", package = "cerExploreData")
  }

  variableNames <- cerUtility::splitAndGetOneBatch(
    "Variable names",
    yamlParams$variableName,
    nBatches,
    batchIndex)

  if (!dir.exists(outDirPath)) {
    dir.create(outDirPath, recursive = TRUE)
  }

  for (variableName in variableNames) {

    yamlParams$variableName <- variableName

    yamlParams$documentTitle <- paste0("Summary of ", yamlParams$variableName)

    databaseName <-
      yamlParams$dataFilePath |>
      basename() |>
      cerUtility::removeFileNameEnding()

    outFileName <- str_glue(outFileNameGlue)

    outFormat <- tolower(outFormat)[[1]]
    if (outFormat == "pdf") {
      outFormat <- "pdf_document"
    } else if (outFormat == "html") {
      outFormat <- "html_document"
    } else if (outFormat == "rmd") {
      return(.summaryOfVariableRmd(yamlParams, rmdSourceFilePath, outDirPath, outFileName))
    } else {
      stop("Unknown format: ", outFormat)
    }

    yamlParams <- expressionsToObject(yamlParams)

    rmarkdown::render(
      rmdSourceFilePath,
      intermediates_dir = tempdir(),
      output_dir = outDirPath,
      output_file = outFileName,
      output_format = outFormat,
      params = yamlParams,
      envir = envir,
      quiet = quiet)
  }
}


.summaryOfVariableRmd <- function(yamlParams, rmdSourceFilePath, outDirPath, outFileName) {
  linesMain <- readLines(rmdSourceFilePath)
  delimiters <- grep("^(---|\\.\\.\\.)\\s*$", linesMain)
  headerMain <- linesMain[(delimiters[1]):(delimiters[2])]
  yml <- yaml::yaml.load(
    headerMain,
    handlers = list(r = function(x) ymlthis::yml_params_code(!!rlang::parse_expr(x))))
  yamlParams <- expressionsToYmlCode(yamlParams)
  baseYaml <- ymlthis::as_yml(yml)
  newYamlParams <- baseYaml$params
  newYamlParams[names(yamlParams)] <- yamlParams
  newYaml <- ymlthis::yml_replace(
    baseYaml,
    params = newYamlParams,
    date = format(Sys.Date()))

  rmdDstFilePath <- file.path(outDirPath, paste0(outFileName, ".Rmd"))
  file.copy(rmdSourceFilePath, rmdDstFilePath)
  ymlthis::use_rmarkdown(
    newYaml,
    path = rmdDstFilePath,
    template = rmdSourceFilePath,
    include_yaml = FALSE,
    overwrite = TRUE,
    quiet = TRUE)
}


expressionsToYmlCode <- function(params) {
  selExpr <- sapply(params, \(x) typeof(x) %in% c("symbol", "language"))
  params[selExpr] <- lapply(
    params[selExpr],
    \(x) ymlthis::yml_params_code(!!x)
  )
  return(params)
}

expressionsToObject <- function(params) {
  selExpr <- sapply(params, \(x) typeof(x) %in% c("symbol", "language"))
  params[selExpr] <- lapply(
    params[selExpr],
    rlang::eval_bare
  )
  return(params)
}
