#
# Shiny App implementation for STAT 697V Homework 5 Presentation, Group 5
#
# Show interactive plots of
#   Fertility vs Life Expectancy Ratio by country
#   Fertility vs Urban Percentage by country
#
# Filter shown points by continent
#   Selectively filter by continent sub-region if a single continent is shown
# Filter by axes values
#   Fertility rate, urban percentage, and urban growth percentage
# Filter by additional data
#   Rural growth percentage
#

library(shiny)
library(tidyverse)
library(plotly)

# Import test data
df = read.csv("test.csv")

df$capital_pop = as.numeric(df$cap_city_pop)
df$urban_pop_percent = as.numeric(df$urban_pop_percent)
df$urban_growth = as.numeric(df$urban_growth)
df$rural_growth = as.numeric(df$rural_growth)
df$cap_percent_pop = as.numeric(df$cap_percent_pop)
df$fertility_rate = as.numeric(df$fertility_rate)

# if capital_pop is NA, label as 0; else 1
df$capital_pop_sign = ifelse(is.na(df$capital_pop), "0", "1")

# if capital_pop is NA, give the value of 1
df$capital_pop1 = ifelse(is.na(df$capital_pop), 1, df$capital_pop)

# if rural_growth<0, label as 0; else 1
df$sign = ifelse(df$rural_growth < 0, "0", "1")

# mark the missing value of rural_growth as missing
df$sign = ifelse(is.na(df$sign), "missing", df$sign)

# Find continents and associated sub-regions from data frame
continents = levels(factor(df$continent))
regions = lapply(continents, function(x) {
  levels(factor(
    df %>%
      filter(continent == x & !is.na(region)) %>%
      pull(region)
  ))
})
names(regions) = continents

# Obtain years in which one or both plots have data that can be displayed
validity =
  df %>%
    mutate(
      valid_fert = !is.na(fertility_rate),
      valid_urb = !is.na(urban_pop_percent),
      valid_grow = !is.na(urban_growth),
      valid = !is.na(fertility_rate) & !(is.na(urban_pop_percent) & is.na(urban_growth))
    ) %>%
    mutate(
      valid_type = ifelse(valid & valid_grow, "valid",
                   ifelse(valid & !valid_grow, "urb_valid_only",
                   ifelse(!valid_grow, "partial_X_only", "no_Y")))
    ) %>%
    group_by(
      year,
      valid_type
    ) %>%
    count() %>%
    pivot_wider(names_from = valid_type, values_from = n) %>%
    select(year, valid, urb_valid_only, no_Y, partial_X_only)

valid_yrs = validity$year[!is.na(validity$valid) | !is.na(validity$urb_valid_only)]
valid_yrs_both_plots = validity$year[!is.na(validity$valid)]


# Define UI for application that shows plots that can be filtered
ui = fluidPage(
  
  # Define UI transitions for showing/hiding extra input controls
  tags$head(
    tags$style(HTML("
      .well {
        max-height: 60rem;
        overflow-y: auto;
      }
      
      #region_filter {
        animation: show 600ms 100ms cubic-bezier(0.38, 0.97, 0.56, 0.76) forwards;
        opacity: 0;
        max-height: 0;
        transform: rotateX(-90deg);
        transform-origin: top center;
      }
      
      #region_filter.input-remove {
        animation: hide 600ms 100ms cubic-bezier(0.38, 0.97, 0.56, 0.76) forwards;
        opacity: 1;
        max-height: 500px;
        transform: none;
        transform-origin: top center;
        margin: 0;
      }
      
      @keyframes show {
        100% {
          opacity: 1;
          max-height: 500px;
          transform: none;
        }
      }
      
      @keyframes hide {
        100% {
          opacity: 0;
          max-height: 0;
          transform: rotateX(-90deg);
        }
      }
    "))
  ),

  # Application title
  titlePanel(
    "Fertility Rate of Countries Based on Urban Concentration",
    windowTitle = "STAT697V HW5"
  ),

  # Sidebar with checkbox and slider inputs based on data 
  sidebarLayout(
      sidebarPanel(
          checkboxGroupInput(
            "cont_filter",
            "Continent",
            choices = continents,
            selected = continents
          ),
          uiOutput("region_filter_ui"),
          selectInput(
            "year_filter",
            "Year(s)",
            choices = valid_yrs,
            selected = valid_yrs_both_plots,
            multiple = TRUE
          ),
          sliderInput(
            "fertility_filter",
            "Fertility Rate (children per women)",
            min = 0.5,
            max = 7.5,
            value = c(0.5, 7.5),
            step = 0.5
          ),
          sliderInput(
            "urban_pcnt_filter",
            "Urban Percentage (% of country population)",
            min = 0,
            max = 100,
            value = c(0, 100),
            step = 5
          ),
          sliderInput(
            "urban_pcnt_growth_filter",
            "Urban Percentage Growth (per year)",
            min = -5,
            max = 30,
            value = c(-5, 10),
            step = 5
          ),
          sliderInput(
            "rural_pcnt_growth_filter",
            "Rural Percentage Growth (per year)",
            min = -20,
            max = 10,
            value = c(-20, 10),
            step = 5
          ),
          
          # Data notes
          hr(),
          span(
            p("Year data encompasses previous 5 years, inclusive*"),
            p(HTML("* <i>2018 data valid for previous 4 years</i>"))
          ),
          
          width = 3 # 1/4 of screen width
      ),

      # Show plots
      mainPanel(
        fillCol(
          plotlyOutput("urban_plot", height = "295px"),
          plotlyOutput("growth_plot", height = "295px"),
          height = "600px"
        )
      )
  )
)

# Set uniform locale for plotting
Sys.setlocale('LC_ALL','C')

ggplot_filter_data = function(data, plot_type, filt_region, yr, fert, urb_pcnt, urb_grow, rur_grow, filt) {
  filter_helper = function(x) {
    if (plot_type == "urban_pcnt") {
      return( x %>% filter(
        year %in% yr,
        between(fertility_rate, fert[1], fert[2]),
        between(urban_pop_percent, urb_pcnt[1], urb_pcnt[2]),
        is.na(urban_growth) | between(urban_growth, urb_grow[1], urb_grow[2]),
        is.na(rural_growth) | between(rural_growth, rur_grow[1], rur_grow[2])
      ))
    }
    return(x %>% filter(
      year %in% yr,
      between(fertility_rate, fert[1], fert[2]),
      between(urban_pop_percent, urb_pcnt[1], urb_pcnt[2]),
      between(urban_growth, urb_grow[1], urb_grow[2]),
      between(rural_growth, rur_grow[1], rur_grow[2])
    ))
  }
  
  if (is.null(yr)) {
    yr = valid_yrs
  }
  
  if (filt_region == TRUE) {
    return(data %>%
      filter(!is.na(region), region %in% filt) %>%
      filter_helper() %>%
        ggplot(aes(y = fertility_rate, color = region))
    )
  }
  
  return(data %>%
    filter(!is.na(continent), continent %in% filt) %>%
    filter_helper() %>%
      ggplot(aes(y = fertility_rate, color = continent))
  )
}

make_plotly = function(data, plot_type, filt_region, ...) {
  plt = ggplot_filter_data(data, plot_type, filt_region, ...)
  plt_n = nrow(plt$data)
  
  if(plot_type == "urban_pcnt") {
    plt_lbls = as.list(plt$data %>%
      transmute(lbl = paste0(
        "<b>Country: ", country, "</b><br>",
        ifelse(filt_region, "Region: ", "Continent: "), ifelse(rep(filt_region, times = plt_n), region, continent), "<br>",
        "Year: ", year, "<br>",
        "Fertility Rate: ", fertility_rate, "<br>",
        "Urban %: ", urban_pop_percent, "<br>",
        "Capital Pop: ", ifelse(capital_pop_sign == "0", "Unspecified", sprintf("%sK", capital_pop1))
      )))[["lbl"]]
    assertthat::are_equal(nrow(plt$data), length(plt_lbls))
    
    plt = plt +
      geom_point(aes(x = urban_pop_percent, size = capital_pop1, text = plt_lbls)) +
      xlab("urban population(percent)") +
      guides(size = "none")
  } else {
    plt_lbls = as.list(plt$data %>%
      transmute(lbl = paste0(
        "<b>Country: ", country, "</b><br>",
        ifelse(filt_region, "Region: ", "Continent: "), ifelse(rep(filt_region, times = plt_n), region, continent), "<br>",
        "Year: ", year, "<br>",
        "Fertility Rate: ", fertility_rate, "<br>",
        "Urban Growth %: ", urban_growth, "<br>",
        "Rural Growth %: ", ifelse(sign == "0", paste0("<b>", rural_growth, "</b>"), rural_growth)
      )))[["lbl"]]
    assertthat::are_equal(nrow(plt$data), length(plt_lbls))
    
    plt = plt +
      geom_point(aes(x = urban_growth, size = abs(rural_growth), shape = sign, text = plt_lbls)) + 
      scale_shape_manual(values = c("0" = 21, "1" = 20), guide = "none") +
      xlab("urban population(percent growth rate)") +
      guides(shape = guide_legend(title = "")) +
      guides(size = guide_legend(title = ""))
  }
  
  plt = plt +
    theme(legend.title = element_blank()) +
    #scale_x_log10() +
    ylim(0, 10) +
    ylab("fertility rate")
  
  return(ggplotly(plt, tooltip = c("text")))
}

# Server helper variables
cont_filter_len = length(continents)
region_filter = NULL
filt_logical_len = NULL

# Define server logic required to draw a histogram
server <- function(input, output) {
  
  # Selectively show sub-region checkboxes
  observeEvent(
    eventExpr = input$cont_filter,
    handlerExpr = {
      # Add region filter if a single continent is being shown
      if (length(input$cont_filter) == 1) {
        region_filter <<- checkboxGroupInput(
          "region_filter",
          paste(input$cont_filter, "Sub-region"),
          choices = regions[[input$cont_filter]],
          selected = regions[[input$cont_filter]]
        )
        output$region_filter_ui = renderUI(region_filter)
        cont_filter_len <<- 1
      } else {
        # Remove region filter only if it was previously inserted
        if (cont_filter_len == 1) {
          output$region_filter_ui = renderUI({
            region_filter %>%
              tagAppendAttributes(
                class = "input-remove"
              )
          })
        }
        cont_filter_len <<- ifelse(is.null(input$cont_filter), 0, length(input$cont_filter))
      }
      filt_logical_len <<- ifelse(length(input$cont_filter) == 1, length(input$region_filter), length(input$cont_filter))
    },
    ignoreNULL = FALSE
  )
  
  # Update number of selections from changes to region filter
  observeEvent(
    eventExpr = input$region_filter,
    handlerExpr = {
      filt_logical_len <<- ifelse(length(input$cont_filter) == 1, length(input$region_filter), length(input$cont_filter))
    },
    ignoreNULL = FALSE
  )

  # Show plot of Fertility vs Urban %
  output$urban_plot = renderPlotly({
    # Verify that continent/region filters are valid, otherwise cancel output
    #  Avoids race condition when displaying region filter for first time
    req(!(length(input$cont_filter) == 1 & is.null(input$region_filter)))
    
    make_plotly(
      df,
      plot_type = "urban_pcnt",
      filt_region = length(input$cont_filter) == 1,
      yr = input$year_filter,
      fert = input$fertility_filter,
      urb_pcnt = input$urban_pcnt_filter,
      urb_grow = input$urban_pcnt_growth_filter,
      rur_grow = input$rural_pcnt_growth_filter,
      filt = ifelse(rep(length(input$cont_filter) == 1, filt_logical_len), input$region_filter, input$cont_filter)
    )
  })
  
  # Show plot of Fertility vs Urban Growth %
  output$growth_plot = renderPlotly({
    # Verify that continent/region filters are valid, otherwise cancel output
    #  Avoids race condition when displaying region filter for first time
    req(!(length(input$cont_filter) == 1 & is.null(input$region_filter)))
    
    make_plotly(
      df,
      plot_type = "urban_growth",
      filt_region = length(input$cont_filter) == 1,
      yr = input$year_filter,
      fert = input$fertility_filter,
      urb_pcnt = input$urban_pcnt_filter,
      urb_grow = input$urban_pcnt_growth_filter,
      rur_grow = input$rural_pcnt_growth_filter,
      filt = ifelse(rep(length(input$cont_filter) == 1, filt_logical_len), input$region_filter, input$cont_filter)
    )
  })
}

# Run the application
shinyApp(ui = ui, server = server)
