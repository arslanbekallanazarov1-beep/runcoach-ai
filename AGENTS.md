# AGENTS.md - Development Rules for AI Coding

## Overview
Rules for AI coding agents working on RunCoach AI MVP. Keep it simple and focused on MVP requirements.

## Key Rules

### 1. Read Documentation Before Changes
- Always read all documentation before making changes
- Search repository for related code before modifying
- Request clarification if documentation is incomplete

### 2. Don't Change Architecture Without Approval
- Never modify core architectural decisions
- Keep separation between deterministic rules and AI explanation
- Don't change database schema without justification

### 3. Only Add MVP Features
- Add only functions documented in MVP.md
- No premature features for future MVP
- Stay within MVP scope

### 4. Minimal Dependencies Only
- Install only dependencies from requirements.txt/setup.py
- No external APIs unless documented
- Use approved package managers only

### 5. Write Tests for Critical Logic
- Write tests for all new functions
- Include unit tests for each component
- Include integration tests for interactions

### 6. Don't Store Secrets in Git
- Never store API keys, passwords, tokens in repository
- Use environment variables for secrets
- Use proper secret management systems

### 7. Make Small Changes
- Make focused, single-responsibility changes
- Minimize impact on existing code
- Keep changes atomic

### 8. Check Existing Code Before Changes
- Review existing code before modifying
- Check dependency versions and compatibility
- Run all tests before changes

### 9. Run Tests After Changes
- Run relevant tests after modifications
- Run linting and style checks
- Run formatting tools

## AI Agent Capabilities

### Allowed Actions
- Read and write files
- Execute bash commands
- Search code and files
- Git operations (commit, push, PR)

### Prohibited Actions
- Change critical architecture
- Write production code without request
- Set up CI/CD systems
- Configure Docker
- Change database schema
- Add new API endpoints

## Daily Routine

### Before Work
1. Read all documentation
2. Search repository for context
3. Run tests to establish baseline
4. Check dependency versions

### After Changes
1. Write commit with clear description
2. Add Co-authored-by: Claude Code
3. Run tests
4. Check linting and formatting

### During Work
1. Check git status regularly
2. Read recent commits
3. Run tests periodically
4. Check linting and formatting

## Learning Objectives

### For AI Agents
- Read documentation before changes
- Check existing code before modifications
- Run tests after changes
- Follow development rules strictly

### Performance Metrics
- Maintain >= 85% code coverage
- All tests passing
- No linting errors
- All builds passing

## Conclusion
Follow these rules for effective and safe AI coding on RunCoach AI MVP. Focus on quality, simplicity, and MVP requirements.