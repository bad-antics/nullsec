#!/usr/bin/env node
import Anthropic from "@anthropic-ai/sdk";
import * as readline from "readline";
import * as fs from "fs";
import * as path from "path";

const client = new Anthropic();

// Create readline interface for user input
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

// Simple question function
function ask(question) {
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      resolve(answer);
    });
  });
}

// MCP Tool: Get multiline input from user
async function getMultilineInput(prompt, options = {}) {
  console.log("\n📝 " + prompt);
  console.log("   (Type 'END' on a new line to finish, or 'CANCEL' to abort)\n");

  const lines = [];
  let line = "";

  while (true) {
    line = await ask("   > ");
    if (line.toUpperCase() === "END") break;
    if (line.toUpperCase() === "CANCEL") return null;
    lines.push(line);
  }

  return lines.join("\n");
}

// MCP Tool: Display confirmation dialog
async function getConfirmation(message) {
  console.log("\n⚠️  " + message);
  const response = await ask("   (yes/no): ");
  return response.toLowerCase().startsWith("y");
}

// MCP Tool: Get selection from options
async function getSelection(prompt, options) {
  console.log("\n🔍 " + prompt);
  options.forEach((opt, i) => {
    console.log(`   ${i + 1}. ${opt}`);
  });

  const answer = await ask("   Select (number): ");
  const index = parseInt(answer) - 1;
  return index >= 0 && index < options.length ? options[index] : null;
}

// Main MCP server logic
async function main() {
  console.log("🚀 Human-In-The-Loop MCP Server Started");
  console.log("   Listening for Copilot requests...\n");

  // Simplified server that handles stdio
  process.stdin.setEncoding("utf-8");

  let buffer = "";

  process.stdin.on("data", async (chunk) => {
    buffer += chunk;
    const lines = buffer.split("\n");
    buffer = lines.pop(); // Keep incomplete line in buffer

    for (const line of lines) {
      if (!line.trim()) continue;

      try {
        const request = JSON.parse(line);

        let response = {
          jsonrpc: "2.0",
          id: request.id,
          result: null,
        };

        if (request.method === "tools/list") {
          response.result = {
            tools: [
              {
                name: "get_multiline_input",
                description:
                  "Get multiline text input from user without consuming Copilot premium",
                inputSchema: {
                  type: "object",
                  properties: {
                    prompt: {
                      type: "string",
                      description: "The prompt to show user",
                    },
                  },
                  required: ["prompt"],
                },
              },
              {
                name: "get_confirmation",
                description:
                  "Get yes/no confirmation from user without consuming premium request",
                inputSchema: {
                  type: "object",
                  properties: {
                    message: {
                      type: "string",
                      description: "The confirmation message",
                    },
                  },
                  required: ["message"],
                },
              },
              {
                name: "get_selection",
                description:
                  "Get user selection from list without consuming premium request",
                inputSchema: {
                  type: "object",
                  properties: {
                    prompt: {
                      type: "string",
                      description: "The selection prompt",
                    },
                    options: {
                      type: "array",
                      items: { type: "string" },
                      description: "Array of options to choose from",
                    },
                  },
                  required: ["prompt", "options"],
                },
              },
            ],
          };
        } else if (request.method === "tools/call") {
          const toolName = request.params.name;
          const args = request.params.arguments;

          let result;

          if (toolName === "get_multiline_input") {
            result = await getMultilineInput(args.prompt);
          } else if (toolName === "get_confirmation") {
            result = await getConfirmation(args.message);
          } else if (toolName === "get_selection") {
            result = await getSelection(args.prompt, args.options);
          }

          response.result = { content: [{ type: "text", text: String(result) }] };
        }

        console.log(JSON.stringify(response));
      } catch (error) {
        console.error("Error:", error.message);
      }
    }
  });
}

main().catch(console.error);

process.on("SIGINT", () => {
  rl.close();
  process.exit(0);
});
