# Engineering Conventions

## Code Conventions

> When writing code, follow these conventions:

- Write simple, verbose code over terse, dense code.
- If a function does not have a corresponding test, mention it.
- When building test, don't mock the system under test.
- Use `@moduledoc` and `@doc` attributes to document modules and functions.
- Write pure functions whenever possible.

## Project Structure

- `lib/`: Contains the source code for the project.
- `test/`: Contains the test code for the project.

## Commit Messages

> When writing commit messages, follow these conventions:

- Use the imperative mood in the subject line.
- Limit the subject line to 50 characters.
- Separate the subject line from the body with a blank line.
- Use conventional commits for semantic versioning.
