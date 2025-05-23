import { NextResponse } from 'next/server';

// The API base URL should be defined in .env.local
const API_BASE_URL = process.env.API_BASE_URL || 'http://localhost:8000';

// Helper function to clean up response data
function formatResponse(text: string): string {
  return text
    // Fix any potential escaped sequences
    .replace(/\\n/g, '\n')
    // Add additional spacing for better readability
    .replace(/\*\*/g, '**')  // Make double asterisks slightly bolder
    .trim();
}

export async function POST(request: Request) {
  try {
    const body = await request.json();
    
    // Forward the request to the FastAPI backend
    const response = await fetch(`${API_BASE_URL}/api/chat/sync`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('API Error:', {
        status: response.status,
        statusText: response.statusText,
        body: errorText
      });
      
      // Return error response
      return new NextResponse(errorText, {
        status: response.status,
        headers: {
          'Content-Type': 'text/plain',
        },
      });
    }

    // Get response as text
    const data = await response.text();
    
    // Format the response text for better display
    const formattedData = formatResponse(data);
    
    // Return the formatted response from the FastAPI backend
    return new NextResponse(formattedData, {
      status: 200,
      headers: {
        'Content-Type': 'text/plain',
      },
    });
  } catch (error) {
    console.error('Server error:', error);
    return new NextResponse('Internal Server Error', { status: 500 });
  }
} 