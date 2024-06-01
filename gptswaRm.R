# Libraries and Options ---------------------------------------------------
if (!require(pacman)) { install.packages("pacman"); library(pacman) }
p_load(openai, httr, jsonlite, future, future.apply)
plan(multisession)

set.seed(42)

# Make a vector of OpenAI instances ---------------------------------------
create_openai_connections <- function(num_threads, sys_msg = "You are a helpful assistant.") {
  connections <- vector("list", num_threads)
  for (i in seq_along(connections)) {
    connections[[i]] <- list(
      id        = paste0("thread_", i),
      messages  = list(list(role = "system", content = sys_msg))
    )
  }
  return(connections)
}

update_thread_response <- function(connection, new_message, 
                                   model = "gpt-4-turbo", 
                                   temperature = max(min(rnorm(1, mean = 1), 1.35), 0), 
                                   top_p = 1, n = 1, stream = FALSE, stop = NULL, 
                                   max_tokens = NULL, presence_penalty = 0, 
                                   frequency_penalty = 0, logit_bias = NULL, 
                                   user = NULL, openai_api_key = Sys.getenv("OPENAI_API_KEY"), 
                                   openai_organization = NULL) {
  # Append the new user message to the conversation history
  connection$messages <- append(connection$messages, list(list(role = "user", content = new_message)))
  
  # Retry mechanism for rate limit handling
  max_retries <- 5
  retries <- 0
  repeat {
    response <- tryCatch({
      openai::create_chat_completion(
        model                = model,
        messages             = connection$messages,
        temperature          = temperature,
        top_p                = top_p,
        n                    = n,
        stream               = stream,
        stop                 = stop,
        max_tokens           = max_tokens,
        presence_penalty     = presence_penalty,
        frequency_penalty    = frequency_penalty,
        logit_bias           = logit_bias,
        user                 = user,
        openai_api_key       = openai_api_key,
        openai_organization  = openai_organization
      )
    }, error = function(e) {
      # Check if the error message contains rate limit information
      if (grepl("Rate limit reached", e$message) || grepl("invalid Unicode output", e$message)) {
        message <- e$message
        if (grepl("Rate limit reached", e$message)) {
          wait_time <- as.numeric(sub(".*Please try again in ([0-9\\.]+)s.*", "\\1", message))
          cat("Rate limit reached. Retrying in", wait_time, "seconds...\n")
          Sys.sleep(wait_time)
        } else {
          cat("Invalid Unicode output detected. Retrying with lower temperature...\n")
          temperature <- max(temperature - 0.2, 0) # Reduce temperature
        }
        retries <- retries + 1
        if (retries >= max_retries) {
          stop("Maximum retries reached. Exiting.")
        }
        NULL
      } else {
        stop(e)
      }
    })
    
    if (!is.null(response)) {
      break
    }
  }
  
  # Extract the assistant's reply from the response
  reply <- response$choices$message.content
  
  # Append the assistant's reply to the conversation history
  connection$messages <- append(connection$messages, 
                                list(list(role = "assistant", content = reply)))
  
  return(connection)
}

# # Test:
# connections      <- create_openai_connections(3, sys_msg = "Answer the question as thoroughly and objectively as possible.")
# connections[[1]] <- update_thread_response(connections[[1]], 
#                                            "What is the capital of India?")
# print(connections[[1]]$messages)
# 
# connections[[1]] <- update_thread_response(connections[[1]], 
#                                            "What country did I ask you about?")
# print(connections[[1]]$messages)



# Make a manager to manage the OpenAI instances ---------------------------
# Create a manager instance
manager <- create_openai_connections(1, sys_msg = "You are the manager. Your role is to synthesize and summarize information from various sources.")[[1]]

# Function to perform web searches using SerpAPI
search_web <- function(query, serp_api_key = Sys.getenv("SERP_KEY")) {
  serp_url <- "https://serpapi.com/search"
  response <- GET(serp_url, query = list(q = query, api_key = serp_api_key))
  search_results <- fromJSON(rawToChar(response$content))
  return(search_results)
}

# User asks the manager a question
user_question <- "What is the capital of India?"
manager       <- update_thread_response(manager, user_question)

# Manager asks all connections the same question and collects their responses
responses <- future_sapply(connections, function(conn) {
  conn <- update_thread_response(conn, user_question)
  conn$messages[[length(conn$messages)]]$content
})

# Display all responses to the manager for synthesis and summarization
synthesis_prompt <- paste("Here are the responses from various connections:", paste(responses, collapse = "\n"))
manager          <- update_thread_response(manager, synthesis_prompt)

# Perform web searches and include the results in the synthesis
google_results <- future({ search_web(user_question) })
bing_results   <- future({ search_web(user_question) })

web_search_summary <- paste("Here are the web search results for Google and Bing:",
                            "Google:", toJSON(value(google_results)),
                            "Bing:", toJSON(value(bing_results)))
web_search_summary <- gsub("https://serpapi.com/[^\\]]+", "", web_search_summary)
web_search_summary <- gsub("\\b.{101,}?\\b", "", web_search_summary)
web_search_summary <- gsub("\\b\\w{60,}?\\b", "", web_search_summary)
web_search_summary <- ifelse(nchar(web_search_summary) > 5000, 
                             web_search_summary[1:5000],
                             web_search_summary)
manager <- update_thread_response(manager, web_search_summary)

# Final synthesis and summarization
final_synthesis_prompt <- "Based on your own knowledge, the responses from connections, and web search results, provide a final answer for the user. Do not add unnecessary boilerplate, commentary, or comments about how you've summarized / synthesized your inputs."
manager <- update_thread_response(manager, final_synthesis_prompt)

# Display the final answer to the user
final_answer <- manager$messages[[length(manager$messages)]]$content
cat(paste("\n", final_answer, "\n"))

# Interactive Prompt ------------------------------------------------------
interactive_prompt <- function(connections, manager, serp_api_key) {
  repeat {
    # Get user input
    user_input <- readline(prompt = "You: ")
    
    # Exit the loop if user types 'exit'
    if (tolower(user_input) == 'exit') {
      cat("Exiting the interactive session.\n")
      break
    }
    
    # Process user input through manager and connections
    manager <- update_thread_response(manager, user_input)
    
    responses <- future_sapply(connections, function(conn) {
      conn <- update_thread_response(conn, user_input)
      conn$messages[[length(conn$messages)]]$content
    })
    
    synthesis_prompt <- paste("Here are the responses from various connections:", paste(responses, collapse = "\n"))
    manager <- update_thread_response(manager, synthesis_prompt)
    
    google_results <- future({ search_web(user_input, serp_api_key) })
    bing_results <- future({ search_web(user_input, serp_api_key) })
    
    web_search_summary <- paste("Here are the web search results for Google and Bing:",
                                "Google:", toJSON(value(google_results)),
                                "Bing:", toJSON(value(bing_results)))
    web_search_summary <- gsub("https://serpapi.com/[^\\]]+", "", web_search_summary)
    web_search_summary <- gsub("\\b.{101,}?\\b", "", web_search_summary)
    web_search_summary <- gsub("\\b\\w{60,}?\\b", "", web_search_summary)
    web_search_summary <- ifelse(nchar(web_search_summary) > 5000, 
                                 web_search_summary[1:5000],
                                 web_search_summary)
    
    manager <- update_thread_response(manager, web_search_summary)
    
    final_synthesis_prompt <- "Based on the responses from connections and web search results, provide a synthesized and summarized answer."
    manager <- update_thread_response(manager, final_synthesis_prompt)
    
    final_answer <- manager$messages[[length(manager$messages)]]$content
    cat(paste("\nAssistant:", final_answer, "\n"))
  }
}


# Initialize interactive session
manager_msg   <- "You are the manager node of a swarm of AIs. Answer the question using your general knowledge, the responses of your worker 'bees' (other bots), and internet sources. Reply to the user. If references or links are available from the swarm-provided information then you may intersperse your response with them or add them at the end as endnotes. Avoid pre-ambles announcing that you're summarizing information or other low-value boilerplate type of statements."
manager       <- create_openai_connections(1, sys_msg = manager_msg)[[1]]
serp_api_key  <- Sys.getenv("SERP_KEY")

interactive_prompt(connections, manager, serp_api_key)
