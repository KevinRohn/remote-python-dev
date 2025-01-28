#!/usr/bin/env python3
"""
Example main script demonstrating remote debugging capabilities.
"""

def calculate_fibonacci(n: int) -> int:
    """Calculate the nth Fibonacci number."""
    if n <= 1:
        return n
    return calculate_fibonacci(n-1) + calculate_fibonacci(n-2)

def main():
    """Main entry point of the application."""
    print("Starting application...")
    
    n = 10
    result = calculate_fibonacci(n)
    
    print(f"The {n}th Fibonacci number is: {result}")

if __name__ == "__main__":
    main()