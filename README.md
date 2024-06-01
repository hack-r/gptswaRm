🔍 **An interactive R script to manage multiple OpenAI API instances and perform web searches using SerpAPI.**

## 📋 Table of Contents

- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Environment Setup](#environment-setup)
- [Usage](#usage)
- [Features](#features)
- [License](#license)

## 📝 Introduction

This script leverages the OpenAI API and SerpAPI to create and manage multiple AI instances. It allows for interactive user input, synthesis of AI responses, and web search results to provide comprehensive answers to user queries.

## 🛠️ Prerequisites

Before you begin, ensure you have met the following requirements:

- R (version 4.0 or later)
- R packages: `pacman`, `openai`, `httr`, `jsonlite`, `future`, `future.apply`
- OpenAI API Key
- SerpAPI Key

## 🌐 Environment Setup

1. Clone this repository to your local machine.
2. Create a `.env` file in the root directory of the project and add your API keys:

```r
# .env
OPENAI_API_KEY=your_openai_api_key_here
SERP_KEY=your_serpapi_key_here
```
Load the environment variables in your R session. You can use the dotenv package for this:

```r
if (!require(dotenv)) { install.packages("dotenv"); library(dotenv) }
dotenv::load_dotenv()
```
## 🚀 Usage

Install the required R packages:

if (!require(pacman)) { install.packages("pacman"); library(pacman) }
pacman::p_load(openai, httr, jsonlite, future, future.apply)
Source the script or run it interactively in your R environment:

Run it interactively in your R IDE. If you want to run it as a headless script, you'll want to cut this out first:

```r
# Final synthesis and summarization
final_synthesis_prompt <- "Based on your own knowledge, the responses from connections, and web search results, provide a final answer for the user. Do not add unnecessary boilerplate, commentary, or comments about how you've summarized / synthesized your inputs."
manager <- update_thread_response(manager, final_synthesis_prompt)

# Display the final answer to the user
final_answer <- manager$messages[[length(manager$messages)]]$content
cat(paste("\n", final_answer, "\n"))
```


## 🌟 Features

Multiple AI Instances: Create and manage multiple OpenAI API instances.
Interactive Session: Engage in an interactive session with the AI.
Web Search Integration: Perform web searches using SerpAPI and synthesize the results.
Error Handling: Robust error handling and retry mechanisms for API rate limits.

## 📜 License

This project is licensed under the MIT License.
