"""
Run browser-use agent on the full WebMall benchmark.

This script runs browser-use with GPT-4.1 on all WebMall tasks excluding
"Add_To_Cart", "Checkout", and "FindAndOrder" (EndToEnd) categories.
Results are saved to study_results_browseruse/ with structure similar to AgentLab.
"""

import asyncio
import os
import json
import time
import traceback
import re
from dotenv import load_dotenv
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Set, Any, Optional

# Load environment variables
current_file = Path(__file__).resolve()
PATH_TO_DOT_ENV_FILE = current_file.parent / ".env"
load_dotenv(PATH_TO_DOT_ENV_FILE)

# Import browser-use components
from browser_use import Agent, ChatOpenAI
from browser_use.browser.profile import BrowserProfile


# ============================================================================
# Configuration
# ============================================================================

# Excluded categories (tasks that require interaction with cart/checkout)
EXCLUDED_CATEGORIES = ["Add_To_Cart", "Checkout", "FindAndOrder"]

# URL mappings for placeholder replacement
URL_MAPPINGS = {
    "{{URL_1}}": os.getenv("SHOP1_URL"),
    "{{URL_2}}": os.getenv("SHOP2_URL"),
    "{{URL_3}}": os.getenv("SHOP3_URL"),
    "{{URL_4}}": os.getenv("SHOP4_URL"),
    "{{URL_5}}": os.getenv("FRONTEND_URL"),
}


# ============================================================================
# Task Loading & Filtering
# ============================================================================


def load_all_tasks(task_sets_path: str) -> List[Dict[str, Any]]:
    """Load all tasks from task_sets.json and filter by category."""
    with open(task_sets_path, "r") as f:
        task_sets = json.load(f)

    all_tasks = []
    for task_set in task_sets:
        for task in task_set.get("tasks", []):
            # Skip excluded categories
            category = task.get("category", "")
            if category in EXCLUDED_CATEGORIES:
                print(f"Skipping task {task['id']} (category: {category})")
                continue

            all_tasks.append(task)

    print(f"\nLoaded {len(all_tasks)} tasks (excluded {EXCLUDED_CATEGORIES})")
    return all_tasks


def prepare_task_instruction(task_config: Dict[str, Any]) -> str:
    """Prepare task instruction by replacing placeholders."""
    # Base replacements for URLs and shop names
    replacements = [
        ("{{URL_1}}", URL_MAPPINGS["{{URL_1}}"]),
        ("{{URL_2}}", URL_MAPPINGS["{{URL_2}}"]),
        ("{{URL_3}}", URL_MAPPINGS["{{URL_3}}"]),
        ("{{URL_4}}", URL_MAPPINGS["{{URL_4}}"]),
        ("{{URL_5}}", URL_MAPPINGS["{{URL_5}}"]),
        ("Shop1", "E-Store Athletes"),
        ("Shop2", "TechTalk"),
        ("Shop3", "CamelCases"),
        ("Shop4", "Hardware Cafe"),
    ]

    # For checkout/order tasks, add user details (though these should be excluded)
    if task_config.get("category") in ["Checkout", "FindAndOrder"]:
        user_details = task_config.get("user_details", {})
        payment_info = task_config.get("payment_info", {})
        if user_details:
            replacements.extend(
                [
                    ("{{name}}", user_details.get("name", "")),
                    ("{{email}}", user_details.get("email", "")),
                    ("{{street}}", user_details.get("street", "")),
                    ("{{house_number}}", user_details.get("house_number", "")),
                    ("{{zip}}", user_details.get("zip", "")),
                    ("{{city}}", user_details.get("city", "")),
                    ("{{state}}", user_details.get("state", "")),
                    ("{{country}}", user_details.get("country", "")),
                ]
            )
        if payment_info:
            replacements.extend(
                [
                    ("{{card}}", payment_info.get("card", "")),
                    ("{{cvv}}", payment_info.get("cvv", "")),
                    ("{{expiry_date}}", payment_info.get("expiry_date", "")),
                ]
            )

    def replace_placeholders(obj, replacements):
        if isinstance(obj, dict):
            return {k: replace_placeholders(v, replacements) for k, v in obj.items()}
        elif isinstance(obj, list):
            return [replace_placeholders(i, replacements) for i in obj]
        elif isinstance(obj, str):
            for placeholder, replacement in replacements:
                obj = obj.replace(placeholder, replacement)
            return obj
        else:
            return obj

    task_config_replaced = replace_placeholders(task_config, replacements)

    # Build full instruction
    general_instruction = task_config_replaced.get("instruction", "")
    specific_instruction = task_config_replaced.get("task", "")
    general_instruction = general_instruction.replace("\\n", "\n")
    specific_instruction = specific_instruction.replace("\\n", "\n")

    full_instruction = general_instruction + specific_instruction

    # Modify submission instructions for browser-use
    old_submission_text = (
        """After solving the task, submit the final result by first navigating to this page:

Solution page: """
        + URL_MAPPINGS["{{URL_5}}"]
        + """

Then fill the final results into the text field on the solution page and press the "Submit Final Result" button.

If the result is one or more product offers enter their exact full URL(s) into the text field separated by three ### characters.
Example submission:
Offer1: """
        + URL_MAPPINGS["{{URL_1}}"]
        + """/product/tp-link-ha100-bluetooth-nfc-music-receiver-provides-wireless-connectivity-to-your-stereo/###Offer2: """
        + URL_MAPPINGS["{{URL_3}}"]
        + """/product/spire-usb-2-0-type-a-cable-male-to-male-1-metre/###Offer3: """
        + URL_MAPPINGS["{{URL_2}}"]
        + """/product/sandberg-usb-c-pd-to-lightning-cable-braided-1-meter-white/

If the result is any other kind of value(s), input the value(s) into the text field.

If there is no result to return after completion of the task, simply enter "Done" into the text field.

Do not forget to press the "Submit Final Result" button in all cases!"""
    )

    new_submission_text = (
        """If a store page does not load, try refreshing it up to three times. If the final result is one or more product offers submit their exact full URL(s) to the user in your final message. Do not put any other URLs apart from your final result URLs into your final answer!
Example submission:
Offer1: """
        + URL_MAPPINGS["{{URL_1}}"]
        + """/product/tp-link-ha100-bluetooth-nfc-music-receiver-provides-wireless-connectivity-to-your-stereo/###Offer2: """
        + URL_MAPPINGS["{{URL_3}}"]
        + """/product/spire-usb-2-0-type-a-cable-male-to-male-1-metre/###Offer3: """
        + URL_MAPPINGS["{{URL_2}}"]
        + """/product/sandberg-usb-c-pd-to-lightning-cable-braided-1-meter-white/

If the final result is any other kind of value(s), submit these values.

If there is no result to return after completion of the task, simply answer "Done" in your final message."""
    )

    full_instruction = full_instruction.replace(
        old_submission_text, new_submission_text
    )

    return full_instruction


# ============================================================================
# Answer Extraction & Validation
# ============================================================================


def extract_answer_from_result(result) -> Set[str]:
    """Extract answer URLs or values from agent's final result.

    Uses the same URL extraction logic as BrowserGym's StringEvaluator
    to ensure consistent parsing.

    Only extracts from the final 'done' action, not intermediate steps.
    """
    if not result:
        return set()

    # Extract the final answer from the last ActionResult where is_done=True
    result_str = ""

    # Handle both actual AgentHistoryList objects and their string representations
    if hasattr(result, "all_results") and result.all_results:
        # Case 1: result is the actual AgentHistoryList object
        for action_result in reversed(result.all_results):
            if hasattr(action_result, "is_done") and action_result.is_done:
                # Get the extracted_content from this final action
                if hasattr(action_result, "extracted_content"):
                    result_str = str(action_result.extracted_content)
                break
    else:
        # Case 2: result is a string representation of AgentHistoryList
        # Extract the final answer from the 'done' action in the string
        result_as_str = str(result)

        # Look for the last occurrence of {'done': {'text': ...
        # This is where the final answer is stored
        # Note: the text value can use either double quotes ("...") or single quotes ('...')
        import re

        # First, try to split by 'done': and extract from the last occurrence
        if "'done':" in result_as_str:
            parts = result_as_str.split("'done':")
            if len(parts) > 1:
                last_part = parts[-1]

                # Try to extract text field - it can be either 'text': "..." or 'text': '...'
                # Try double quotes first (more common with newlines)
                text_match = re.search(
                    r"'text':\s*\"((?:[^\"]|\\\")*?)\"", last_part, re.DOTALL
                )
                if text_match:
                    result_str = text_match.group(1)
                    # Unescape escaped characters
                    result_str = result_str.replace('\\"', '"')
                    result_str = result_str.replace("\\'", "'")
                else:
                    # Try single quotes
                    text_match = re.search(
                        r"'text':\s*'((?:[^']|\\')*?)'", last_part, re.DOTALL
                    )
                    if text_match:
                        result_str = text_match.group(1)
                        # Unescape escaped characters
                        result_str = result_str.replace("\\'", "'")

    # If we couldn't extract a final answer from the done action, return empty set
    # DO NOT use the entire result string as it contains intermediate navigation URLs
    if not result_str:
        return set()

    # Replace escaped newlines with actual newlines (handles both \n and \\n)
    result_str = result_str.replace("\\n", "\n")

    # Replace ### with newlines to ensure regex works (same as BrowserGym)
    result_str = result_str.replace("###", "\n")

    # Extract all URLs using an improved regex pattern
    # This pattern matches full URLs including paths with special characters
    # IMPORTANT: Only match URLs that have http:// or https:// protocol
    # This prevents false positives like "NodeType.ELEMENT"
    URL_RE = re.compile(
        r"""\b
            (?:https?://)                           # REQUIRED http:// or https://
            (?:                                     # ── host ─────────────────────
                  localhost                         #   localhost
                | (?:\d{1,3}(?:\.\d{1,3}){3})       #   IPv4 like 127.0.0.1
                | (?:[A-Za-z0-9-]+\.)+[A-Za-z]{2,}  # domain.tld (with sub-domains)
            )
            (?::\d{2,5})?                           # optional :port
            (?:/[^\s<>"{}|\\^`\[\]]*)?              # optional /path (stop at whitespace or special chars)
        """,
        re.VERBOSE | re.IGNORECASE,
    )

    urls = [m.group(0) for m in URL_RE.finditer(result_str)]

    # Normalize URLs (remove trailing slashes and clean up)
    def normalize_url(url: str) -> str:
        """Normalize URL by removing trailing slashes and problematic characters."""
        # Remove trailing punctuation, whitespace, and escaped characters
        url = url.rstrip(".,;:!?\n\r\t \\")
        # Remove trailing slash
        url = url.rstrip("/")
        return url

    cleaned_urls = set()
    for url in urls:
        normalized = normalize_url(url)
        if normalized:  # Only add non-empty URLs
            cleaned_urls.add(normalized)

    return cleaned_urls


def get_expected_answers(task_config: Dict[str, Any]) -> Set[str]:
    """Extract expected answers from task definition and replace placeholders.

    Normalizes URLs to match the format used in extract_answer_from_result.
    """

    def normalize_url(url: str) -> str:
        """Normalize URL by removing trailing slashes."""
        return url.rstrip("/")

    expected_answers = set()

    if "correct_answer" in task_config:
        correct_answer = task_config["correct_answer"]

        if isinstance(correct_answer, dict) and "answers" in correct_answer:
            answers = correct_answer["answers"]
            if isinstance(answers, list):
                for answer in answers:
                    if isinstance(answer, str):
                        # Replace URL placeholders
                        actual_url = answer
                        for placeholder, real_url in URL_MAPPINGS.items():
                            actual_url = actual_url.replace(placeholder, real_url)
                        # Normalize the URL
                        actual_url = normalize_url(actual_url)
                        expected_answers.add(actual_url)
                    else:
                        expected_answers.add(str(answer))
            else:
                # Single answer
                if isinstance(answers, str):
                    actual_url = answers
                    for placeholder, real_url in URL_MAPPINGS.items():
                        actual_url = actual_url.replace(placeholder, real_url)
                    # Normalize the URL
                    actual_url = normalize_url(actual_url)
                    expected_answers.add(actual_url)
                else:
                    expected_answers.add(str(answers))
        elif isinstance(correct_answer, str):
            actual_url = correct_answer
            for placeholder, real_url in URL_MAPPINGS.items():
                actual_url = actual_url.replace(placeholder, real_url)
            # Normalize the URL
            actual_url = normalize_url(actual_url)
            expected_answers.add(actual_url)

    return expected_answers


def calculate_metrics(expected: Set[str], actual: Set[str]) -> Dict[str, float]:
    """Calculate precision, recall, F1, and task completion.

    Handles edge cases:
    - Both empty: perfect match (all metrics = 1.0)
    - Only actual empty: zero recall
    - Only expected empty: zero precision (shouldn't happen in WebMall)
    """
    # Task completion: exact match
    task_completion = 1.0 if expected == actual else 0.0

    # Edge case: both empty is a perfect match
    if len(expected) == 0 and len(actual) == 0:
        return {
            "task_completion": 1.0,
            "precision": 1.0,
            "recall": 1.0,
            "f1_score": 1.0,
        }

    # Precision: correct predictions / total predictions
    if len(actual) > 0:
        precision = len(expected.intersection(actual)) / len(actual)
    else:
        precision = 0.0

    # Recall: correct predictions / total expected
    if len(expected) > 0:
        recall = len(expected.intersection(actual)) / len(expected)
    else:
        recall = 0.0

    # F1 score: harmonic mean of precision and recall
    if precision + recall > 0:
        f1_score = 2 * (precision * recall) / (precision + recall)
    else:
        f1_score = 0.0

    return {
        "task_completion": task_completion,
        "precision": precision,
        "recall": recall,
        "f1_score": f1_score,
    }


# ============================================================================
# Agent Execution
# ============================================================================


async def run_agent_on_task(
    task_config: Dict[str, Any],
    task_seed: int,
    max_steps: int,
    model: str = "gpt-4.1-2025-04-14",
    temperature: float = 0.01,
    gif_output_path: Optional[str] = None,
    use_vision: bool = True,
) -> Dict[str, Any]:
    """Run browser-use agent on a single task and return results."""
    task_id = task_config["id"]
    category = task_config.get("category", "Unknown")

    print(f"\n{'='*80}")
    print(f"Running task: {task_id} (seed: {task_seed})")
    print(f"Category: {category}")
    print(f"{'='*80}\n")

    # Prepare task instruction
    full_instruction = prepare_task_instruction(task_config)

    # Initialize LLM
    llm = ChatOpenAI(
        model=model,
        temperature=temperature,
    )

    # Create browser profile with page load wait times matching BrowserGym
    # BrowserGym waits 0.5s after action + 3s for DOM load = ~3.5s total
    browser_profile = BrowserProfile(
        minimum_wait_page_load_time=0.5,  # Match BrowserGym's 0.5s wait after actions
        wait_for_network_idle_page_load_time=6.0,  # Match BrowserGym's 3s DOM load timeout
    )

    # Create agent
    agent = Agent(
        task=full_instruction,
        llm=llm,
        generate_gif=gif_output_path if gif_output_path else False,
        calculate_cost=True,
        browser_profile=browser_profile,
        use_vision=use_vision,
    )

    # Track timing
    start_time = time.time()

    # Run agent
    result = None
    error = None
    stack_trace = None

    try:
        result = await agent.run(max_steps=max_steps)
    except Exception as e:
        error = str(e)
        stack_trace = traceback.format_exc()
        print(f"❌ Error during execution: {error}")

    end_time = time.time()
    elapsed_time = end_time - start_time

    # Extract answers
    expected_answers = get_expected_answers(task_config)
    actual_answers = extract_answer_from_result(result) if result else set()

    # Calculate metrics
    metrics = calculate_metrics(expected_answers, actual_answers)

    # Get usage/cost information from agent.history.usage
    usage_info = {}
    token_stats = {}
    cost_stats = {}

    if (
        hasattr(agent, "history")
        and hasattr(agent.history, "usage")
        and agent.history.usage
    ):
        usage = agent.history.usage

        # Extract token statistics
        if hasattr(usage, "total_input_tokens"):
            token_stats["total_input_tokens"] = usage.total_input_tokens
        if hasattr(usage, "total_output_tokens"):
            token_stats["total_output_tokens"] = usage.total_output_tokens
        if hasattr(usage, "total_tokens"):
            token_stats["total_tokens"] = usage.total_tokens

        # Extract cost statistics
        if hasattr(usage, "total_cost"):
            cost_stats["total_cost"] = usage.total_cost
        if hasattr(usage, "input_cost"):
            cost_stats["input_cost"] = usage.input_cost
        if hasattr(usage, "output_cost"):
            cost_stats["output_cost"] = usage.output_cost

        usage_info = {"tokens": token_stats, "costs": cost_stats}

    # Get number of steps and detect truncation
    n_steps = len(agent.history.history) if hasattr(agent, "history") else 0

    # Detect if task was truncated (reached max_steps without completing)
    truncated = False
    if hasattr(agent, "history") and agent.history.history:
        last_history = agent.history.history[-1]
        if hasattr(last_history, "result") and last_history.result:
            # Check if any action in the last step marked as done
            is_done = any(
                r.is_done for r in last_history.result if hasattr(r, "is_done")
            )
            # Task is truncated if we reached max_steps but didn't mark as done
            truncated = (n_steps >= max_steps) and not is_done

    # Prepare result summary
    task_result = {
        "task_id": task_id,
        "task_seed": task_seed,
        "category": category,
        "task_description": task_config.get("task", ""),
        "expected_answers": list(expected_answers),
        "actual_answers": list(actual_answers),
        "missing_answers": list(expected_answers - actual_answers),
        "extra_answers": list(actual_answers - expected_answers),
        "task_completion": metrics["task_completion"],
        "precision": metrics["precision"],
        "recall": metrics["recall"],
        "f1_score": metrics["f1_score"],
        "n_steps": n_steps,
        "time_elapsed": elapsed_time,
        "truncated": truncated,
        "terminated": error is None,
        "error": error,
        "stack_trace": stack_trace,
        "result": str(result) if result else None,
        "usage_info": usage_info,
    }

    return task_result, agent


# ============================================================================
# Result Saving
# ============================================================================


def save_task_results(task_result: Dict[str, Any], agent: Agent, task_dir: Path):
    """Save task results to the task directory."""
    task_dir.mkdir(parents=True, exist_ok=True)

    # Save task summary
    task_summary = {
        "task_id": task_result["task_id"],
        "task_seed": task_result["task_seed"],
        "category": task_result["category"],
        "task_completion": task_result["task_completion"],
        "precision": task_result["precision"],
        "recall": task_result["recall"],
        "f1_score": task_result["f1_score"],
        "expected_answers": task_result["expected_answers"],
        "actual_answers": task_result["actual_answers"],
        "missing_answers": task_result["missing_answers"],
        "extra_answers": task_result["extra_answers"],
    }

    with open(task_dir / "task_summary.json", "w") as f:
        json.dump(task_summary, f, indent=2)

    # Extract per-step statistics from agent history
    per_step_stats = []
    step_timing_stats = {
        "per_step_durations": [],
        "total_duration": 0.0,
        "max_step_duration": 0.0,
        "min_step_duration": float("inf"),
    }

    if hasattr(agent, "history") and agent.history.history:
        for history_item in agent.history.history:
            step_data = {}

            # Get step timing if available
            if hasattr(history_item, "metadata") and history_item.metadata:
                metadata = history_item.metadata
                if hasattr(metadata, "duration_seconds"):
                    duration = metadata.duration_seconds
                    step_timing_stats["per_step_durations"].append(duration)
                    step_timing_stats["total_duration"] += duration
                    step_timing_stats["max_step_duration"] = max(
                        step_timing_stats["max_step_duration"], duration
                    )
                    step_timing_stats["min_step_duration"] = min(
                        step_timing_stats["min_step_duration"], duration
                    )
                    step_data["duration_seconds"] = duration

                if hasattr(metadata, "step_number"):
                    step_data["step_number"] = metadata.step_number

            # Get model output (thinking, actions, etc.)
            if hasattr(history_item, "model_output") and history_item.model_output:
                model_output = history_item.model_output
                if hasattr(model_output, "thinking") and model_output.thinking:
                    step_data["thinking"] = model_output.thinking
                if (
                    hasattr(model_output, "evaluation_previous_goal")
                    and model_output.evaluation_previous_goal
                ):
                    step_data["evaluation_previous_goal"] = (
                        model_output.evaluation_previous_goal
                    )
                if hasattr(model_output, "memory") and model_output.memory:
                    step_data["memory"] = model_output.memory
                if hasattr(model_output, "next_goal") and model_output.next_goal:
                    step_data["next_goal"] = model_output.next_goal

                # Extract actions
                if hasattr(model_output, "action"):
                    actions = []
                    for action in model_output.action:
                        # Convert action to dict
                        action_dict = (
                            action.model_dump() if hasattr(action, "model_dump") else {}
                        )
                        actions.append(action_dict)
                    step_data["actions"] = actions

            # Get action results
            if hasattr(history_item, "result"):
                results = []
                for result in history_item.result:
                    result_dict = (
                        result.model_dump() if hasattr(result, "model_dump") else {}
                    )
                    results.append(result_dict)
                step_data["results"] = results

            # Get browser state (URL)
            if hasattr(history_item, "state") and history_item.state:
                state = history_item.state
                if hasattr(state, "url"):
                    step_data["url"] = state.url

            per_step_stats.append(step_data)

    # Fix min_step_duration if no steps were recorded
    if step_timing_stats["min_step_duration"] == float("inf"):
        step_timing_stats["min_step_duration"] = 0.0

    # Save summary info (steps, cost, timing)
    summary_info = {
        "n_steps": task_result["n_steps"],
        "time_elapsed": task_result["time_elapsed"],
        "usage_info": task_result["usage_info"],
        "step_timing": step_timing_stats,
        "error": task_result["error"],
        "terminated": task_result["terminated"],
        "truncated": task_result["truncated"],
    }

    with open(task_dir / "summary_info.json", "w") as f:
        json.dump(summary_info, f, indent=2)

    # Save detailed per-step trajectory
    trajectory = {"task_id": task_result["task_id"], "steps": per_step_stats}

    with open(task_dir / "trajectory.json", "w") as f:
        json.dump(trajectory, f, indent=2)

    # Save full task result
    with open(task_dir / "full_result.json", "w") as f:
        json.dump(task_result, f, indent=2)

    # Save full agent history using browser-use's built-in method
    if hasattr(agent, "history"):
        try:
            agent.history.save_to_file(task_dir / "agent_history.json")
        except Exception as e:
            print(f"Warning: Could not save agent history: {e}")


def save_study_summary(all_results: List[Dict[str, Any]], study_dir: Path):
    """Save aggregated study summary."""
    # Overall metrics
    total_tasks = len(all_results)

    if total_tasks == 0:
        print("No results to summarize")
        return

    # Calculate token and cost aggregates
    total_tokens = 0
    total_input_tokens = 0
    total_output_tokens = 0
    total_cost = 0.0
    tasks_with_usage = 0

    for r in all_results:
        usage_info = r.get("usage_info", {})
        if usage_info:
            tokens = usage_info.get("tokens", {})
            costs = usage_info.get("costs", {})

            # Count task if it has usage data (check for key existence, not truthiness)
            if "total_tokens" in tokens:
                total_tokens += tokens["total_tokens"]
                tasks_with_usage += 1
            if "total_input_tokens" in tokens:
                total_input_tokens += tokens["total_input_tokens"]
            if "total_output_tokens" in tokens:
                total_output_tokens += tokens["total_output_tokens"]
            if "total_cost" in costs:
                total_cost += costs["total_cost"]

    avg_metrics = {
        "num_total_runs": total_tasks,
        "avg_task_completion_rate": sum(r["task_completion"] for r in all_results)
        / total_tasks,
        "avg_precision": sum(r["precision"] for r in all_results) / total_tasks,
        "avg_recall": sum(r["recall"] for r in all_results) / total_tasks,
        "avg_f1_score": sum(r["f1_score"] for r in all_results) / total_tasks,
        "avg_steps": sum(r["n_steps"] for r in all_results) / total_tasks,
        "avg_time_elapsed": sum(r["time_elapsed"] for r in all_results) / total_tasks,
        "terminated_rate": sum(1 for r in all_results if r["terminated"]) / total_tasks,
        "truncated_rate": sum(1 for r in all_results if r.get("truncated", False))
        / total_tasks,
        "total_tokens": total_tokens,
        "total_input_tokens": total_input_tokens,
        "total_output_tokens": total_output_tokens,
        "total_cost": total_cost,
        "avg_tokens_per_task": (
            total_tokens / tasks_with_usage if tasks_with_usage > 0 else 0
        ),
        "avg_cost_per_task": (
            total_cost / tasks_with_usage if tasks_with_usage > 0 else 0
        ),
    }

    # By task type
    by_task_type = {}
    for result in all_results:
        category = result["category"]
        if category not in by_task_type:
            by_task_type[category] = []
        by_task_type[category].append(result)

    task_type_summaries = {}
    for category, results in by_task_type.items():
        n_tasks = len(results)

        # Calculate token and cost aggregates for this category
        cat_total_tokens = 0
        cat_total_cost = 0.0
        cat_tasks_with_usage = 0

        for r in results:
            usage_info = r.get("usage_info", {})
            if usage_info:
                tokens = usage_info.get("tokens", {})
                costs = usage_info.get("costs", {})

                # Count task if it has usage data (check for key existence, not truthiness)
                if "total_tokens" in tokens:
                    cat_total_tokens += tokens["total_tokens"]
                    cat_tasks_with_usage += 1
                if "total_cost" in costs:
                    cat_total_cost += costs["total_cost"]

        task_type_summaries[category] = {
            "summary": {
                "num_runs": n_tasks,
                "avg_task_completion_rate": sum(r["task_completion"] for r in results)
                / n_tasks,
                "avg_precision": sum(r["precision"] for r in results) / n_tasks,
                "avg_recall": sum(r["recall"] for r in results) / n_tasks,
                "avg_f1_score": sum(r["f1_score"] for r in results) / n_tasks,
                "avg_steps": sum(r["n_steps"] for r in results) / n_tasks,
                "avg_time_elapsed": sum(r["time_elapsed"] for r in results) / n_tasks,
                "terminated_rate": sum(1 for r in results if r["terminated"]) / n_tasks,
                "truncated_rate": sum(1 for r in results if r.get("truncated", False))
                / n_tasks,
                "total_tokens": cat_total_tokens,
                "total_cost": cat_total_cost,
                "avg_tokens_per_task": (
                    cat_total_tokens / cat_tasks_with_usage
                    if cat_tasks_with_usage > 0
                    else 0
                ),
                "avg_cost_per_task": (
                    cat_total_cost / cat_tasks_with_usage
                    if cat_tasks_with_usage > 0
                    else 0
                ),
            },
            "tasks": [
                {
                    "task_id": r["task_id"],
                    "task_seed": r["task_seed"],
                    "task_completion": r["task_completion"],
                    "precision": r["precision"],
                    "recall": r["recall"],
                    "f1_score": r["f1_score"],
                    "n_steps": r["n_steps"],
                    "truncated": r.get("truncated", False),
                    "terminated": r["terminated"],
                    "error": r["error"],
                }
                for r in results
            ],
        }

    study_summary = {"overall": avg_metrics, "by_task_type": task_type_summaries}

    with open(study_dir / "study_summary.json", "w") as f:
        json.dump(study_summary, f, indent=2)

    print(f"\n{'='*80}")
    print("STUDY SUMMARY")
    print(f"{'='*80}")
    print(f"Total tasks: {total_tasks}")
    print(f"Task completion rate: {avg_metrics['avg_task_completion_rate']:.2%}")
    print(f"Average precision: {avg_metrics['avg_precision']:.2%}")
    print(f"Average recall: {avg_metrics['avg_recall']:.2%}")
    print(f"Average F1 score: {avg_metrics['avg_f1_score']:.2%}")
    print(f"Average steps: {avg_metrics['avg_steps']:.1f}")
    print(f"Average time: {avg_metrics['avg_time_elapsed']:.1f}s")
    print(f"Terminated rate: {avg_metrics['terminated_rate']:.2%}")
    print(f"Truncated rate: {avg_metrics['truncated_rate']:.2%}")
    print(f"Total tokens: {total_tokens:,}")
    print(f"Total cost: ${total_cost:.4f}")
    print(f"Avg tokens/task: {avg_metrics['avg_tokens_per_task']:.0f}")
    print(f"Avg cost/task: ${avg_metrics['avg_cost_per_task']:.4f}")
    print(f"\nResults saved to: {study_dir}")


# ============================================================================
# Main Study Runner
# ============================================================================


async def run_study(
    max_steps: int = 30,
    model: str = "gpt-4.1-2025-04-14",
    temperature: float = 0.01,
    task_limit: Optional[int] = None,
    output_dir: Optional[str] = None,
    use_vision: bool = True,
):
    """Run the full study on WebMall tasks."""
    # Paths
    script_dir = Path(__file__).parent
    task_sets_env = os.getenv("TASKSET_PATH")
    task_sets_path = Path(task_sets_env) if task_sets_env else (
        script_dir / "Browsergym/browsergym/webmall/src/browsergym/webmall/task_sets.json"
    )

    out_dir_env = os.getenv("RESULTS_DIR")
    output_dir = Path(out_dir_env) if out_dir_env else (script_dir / "study_results_browseruse")

    if output_dir is None:
        output_dir = script_dir / "study_results_browseruse"
    else:
        output_dir = Path(output_dir)

    # Create study directory
    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    study_name = f"{timestamp}_browseruse-gpt-4.1-on-webmall"
    study_dir = output_dir / study_name
    study_dir.mkdir(parents=True, exist_ok=True)

    print(f"Study directory: {study_dir}")

    # Load tasks
    all_tasks = load_all_tasks(str(task_sets_path))

    # Limit tasks if specified
    if task_limit:
        all_tasks = all_tasks[:task_limit]
        print(f"Limited to {task_limit} tasks for testing")

    # Run each task
    all_results = []
    for i, task_config in enumerate(all_tasks, 1):
        task_id = task_config["id"]
        task_seed = 0  # Default seed

        print(f"\n[{i}/{len(all_tasks)}] Running {task_id}...")

        # Prepare task directory and gif path
        task_folder_name = f"{timestamp}_browseruse_on_{task_id}_{task_seed}"
        task_dir = study_dir / task_folder_name
        task_dir.mkdir(parents=True, exist_ok=True)
        gif_output_path = str(task_dir / "agent_history.gif")

        # Run task
        task_result, agent = await run_agent_on_task(
            task_config,
            task_seed,
            max_steps,
            model,
            temperature,
            gif_output_path,
            use_vision,
        )

        # Save results
        save_task_results(task_result, agent, task_dir)

        all_results.append(task_result)

        # Print brief status
        status = "✅ SUCCESS" if task_result["task_completion"] == 1.0 else "❌ FAILED"
        print(
            f"{status} - Precision: {task_result['precision']:.2%}, Recall: {task_result['recall']:.2%}"
        )

    # Save study summary
    save_study_summary(all_results, study_dir)


# ============================================================================
# Entry Point
# ============================================================================


def main():
    """Main entry point."""
    # Check API key
    if not os.getenv("OPENAI_API_KEY"):
        print("ERROR: OPENAI_API_KEY not found in environment variables.")
        print("Please set it in your .env file or export it.")
        exit(1)

    # Configuration
    max_steps = 50
    model = "gpt-4.1-2025-04-14"
    # temperature = 0.01
    task_limit = None  # Set to a number for testing, None for full run
    use_vision = False  # Set to False to disable vision/screenshot processing

    # Run study
    asyncio.run(
        run_study(
            max_steps=max_steps,
            model=model,
            # temperature=temperature,
            task_limit=task_limit,
            use_vision=use_vision,
        )
    )


if __name__ == "__main__":
    main()
