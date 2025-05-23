# Ship360 Assistant

A modern web interface for managing shipping operations through natural language interactions. Built with Next.js 14, TypeScript, and Tailwind CSS. This frontend provides an intuitive chat-based interface for shipping operations including rate shopping, label creation, shipment tracking, and shipment management.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- 🚢 **Natural Language Shipping**: Chat-based interface for all shipping operations
- 📦 **Rate Shopping**: Compare shipping rates across multiple carriers (UPS, FedEx, USPS)
- 🏷️ **Label Generation**: Create shipping labels with carrier selection
- 📍 **Shipment Tracking**: Track packages using tracking numbers
- 📋 **Shipment Management**: View and manage existing shipments
- 🎯 **Smart Action Buttons**: Pre-built actions for common shipping operations
- 📱 **Parameter Forms**: Intuitive forms for complex shipping parameters
- 🌙 **Dark/Light Theme**: Adaptive UI with theme switching
- 💾 **Recent Actions**: History of recent shipping actions
- 🔄 **Mock Mode**: Development mode with sample data
- 🚀 **Responsive Design**: Mobile-friendly interface

## Tech Stack

- **Framework**: Next.js 14 (App Router)
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **UI Components**: Shadcn UI (Radix UI primitives)
- **State Management**: React Hooks
- **HTTP Client**: Native Fetch API
- **Development Mode**: HTTP/HTTPS options with SSL certificates
- **Backend Integration**: Ship360 Chat API (FastAPI)

## Architecture

The application follows a modern React architecture with:

- **Chat Interface**: Real-time messaging with AI assistant
- **Action System**: Pre-built actions for common shipping operations
- **Parameter Forms**: Dynamic forms with validation for complex operations
- **Mock Mode**: Development environment with sample shipping data
- **Theme System**: Dark/light mode with system preference detection

## Getting Started

### Prerequisites

- Node.js 18+ 
- npm or yarn
- Ship360 Chat API backend (FastAPI)
- Access to Ship360 shipping services

### Installation

1. Clone the repository:
```bash
git clone https://github.com/your-repo/Ship360-CW.git
cd Ship360-CW/ship360-ui
```

2. Install dependencies:
```bash
npm install
```

3. Create a `.env.local` file:
```env
```

### Development

Start the development server:
```bash
npm run dev
```

You'll be prompted to choose:
1. **HTTP** (Port 3000) - Standard development
2. **HTTPS** (Port 3443) - Secure development with SSL certificates

The application will open at:
- HTTP: `http://localhost:3000`
- HTTPS: `https://localhost:3443`

### Building for Production

```bash
npm run build
npm run start
```

## Environment Variables

Create a `.env.local` file in the root directory with the following variables:

```env
  # Server-side only (not exposed to browser)
  API_BASE_URL=http://localhost:8000
  # Client-side environment variables (must be prefixed with NEXT_PUBLIC_)
  NEXT_PUBLIC_API_CONFIGURED=true
  API_KEY=1234
```

### Environment Variable Descriptions

- `API_BASE_URL`: Ship360 Chat API backend URL (default: http://localhost:8000)
- `NNEXT_PUBLIC_API_CONFIGURED`: Can change to false which enables mock mode.
- `API_KEY`: API authentication key for backend communication (not used)

## Available Shipping Operations

The Ship360 Assistant supports the following shipping operations through natural language chat and action buttons:

### � **Rate Shopping Operations**
- **Rate Shop by Package**: Compare shipping rates for a package with specific dimensions and weight
- **Rate Shop for Order**: Find shipping rates for an existing order
- Price filtering and delivery time constraints
- Multi-carrier comparison (UPS, FedEx, USPS)

### 🏷️ **Label Generation Operations**  
- **Create Label for Order**: Generate shipping labels for existing orders with delivery preferences
- **Generate Label**: Create shipping labels with specific carrier service selection
- Carrier selection from UPS, FedEx, USPS services
- Delivery speed options and cost optimization

### 📍 **Tracking Operations**
- **Track Shipments**: Get real-time tracking information using tracking numbers
- **Get Shipments**: View and manage existing shipments with date filtering
- Tracking history and delivery status updates

### 📋 **Shipment Management**
- **Cancel Shipments**: Cancel existing shipments by shipment ID
- **Shipment History**: View shipments with optional date filtering
- Status monitoring and shipment details

Each operation supports both natural language prompts and structured parameter forms for complex operations.

## Mock Mode

Enable mock mode to test the interface without a backend connection:
- Toggle available in the UI
- Pre-configured shipping responses
- Sample rate shopping data
- Mock tracking information
- No API connection required

Perfect for development and testing shipping workflows without hitting actual shipping APIs.

## Deployment

The application is designed for deployment to various platforms:

### Azure App Service
- Builds with `npm run build`
- Runs with `npm run start`
- Environment variables configured in App Service Configuration
- Supports Azure Easy Auth for authentication

### Docker Deployment
- Containerized deployment support
- Environment variables passed via container configuration
- SSL certificate support for HTTPS

### Development Requirements
- Node.js 18+
- Ship360 Chat API backend running
- Proper environment variables configured

## Project Structure

```
app/                     # Next.js app router
├── api/                # API routes
│   ├── chat/           # Chat API proxy to backend
│   └── action/         # Action handling
├── globals.css         # Global styles
├── layout.tsx          # Root layout
├── page.tsx            # Main chat interface
└── providers.tsx       # Theme and context providers

components/             # React components
├── ui/                # Shadcn UI components (button, input, etc.)
├── action-buttons.tsx  # Shipping action buttons
├── action-parameters-dialog.tsx  # Parameter forms
├── form-section.tsx    # Collapsible form sections
├── message-bubble.tsx  # Chat message display
├── recent-actions.tsx  # Recent action history
└── theme-switcher.tsx  # Dark/light theme toggle

lib/                   # Utilities and configuration
├── config.ts          # Environment configuration
├── mockData.ts        # Mock responses for development
└── utils.ts           # Utility functions

types/                 # TypeScript type definitions
├── actions.ts         # Action and parameter types
├── api.ts             # API request/response types
└── chat.ts            # Chat message types

scripts/               # Development scripts
└── dev-prompt.js      # Development server selection

certificates/          # SSL certificates for HTTPS development
├── localhost.pem      # SSL certificate (not tracked in git)
└── localhost-key.pem  # SSL private key (not tracked in git)
```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details. 

## Key Features & Components

### Collapsible Form Sections

The Ship360 Assistant includes collapsible form sections to improve user experience for complex shipping operations with multiple parameters.

#### Features:
- **Organized Form Fields**: Logical grouping of shipping parameters (weight, dimensions, addresses)
- **Expandable Sections**: Better space management for complex operations like rate shopping
- **Smooth Animations**: Enhanced user experience with section transitions  
- **Mobile Responsive**: Optimized for mobile shipping operations

#### Shipping Use Cases:
- **Rate Shopping Forms**: Weight, dimensions, origin/destination addresses
- **Label Creation**: Order details, carrier selection, delivery preferences
- **Tracking Forms**: Tracking number input with carrier selection

#### Example Usage:

```jsx
import { FormSection } from '@/components/form-section'

function ShippingForm() {
  return (
    <form>
      <FormSection title="Package Details" defaultOpen={true}>
        <input placeholder="Weight" />
        <input placeholder="Dimensions" />
      </FormSection>
      
      <FormSection title="Addresses" defaultOpen={false}>
        <input placeholder="Origin Address" />
        <input placeholder="Destination Address" />
      </FormSection>
    </form>
  )
}
```

### Action System

The application features a comprehensive action system for common shipping operations:

- **Quick Actions**: Pre-built buttons for rate shopping, label creation, tracking
- **Parameter Forms**: Dynamic forms with validation for complex shipping parameters  
- **Recent Actions**: History of shipping operations for quick reuse
- **Smart Templates**: Natural language prompt templates with parameter substitution

### Required Dependencies

All necessary UI dependencies are included in package.json:
- `@radix-ui/react-collapsible` - Collapsible form sections
- `@radix-ui/react-checkbox` - Form checkboxes  
- `@radix-ui/react-select` - Dropdown selections
- `@radix-ui/react-dialog` - Modal dialogs
- `lucide-react` - Icons for shipping operations

Run `npm install` to ensure all dependencies are installed.

## Test Prompts

Try these example prompts to test the Ship360 Assistant functionality:

### Rate Shopping
- "Rate shop for the best shipping option for this package: 10x6x4 inches, 2 lbs, shipping from 10001 to 94105"
- "Compare rates for FedEx, UPS, and USPS for a shipment from Atlanta to Seattle, and select the most cost-effective with tracking"
- "Find the most cost-effective shipping option for a 2 lb package measuring 10x6x4 inches from ZIP 10001 to 94105"

### Label Creation  
- "Create a shipping label for Order #1005101 using the cheapest available carrier with delivery within 3 days"
- "Generate a shipping label with the fastest delivery time under $15 for order #1005202"

### Tracking
- "Track shipment with tracking number [your-tracking-number]"
- "Show me all shipments from the last 7 days"

### General Shipping
- "What's the best shipping method for a 2-pound box from ZIP 10001 to 94105 with a 3-day delivery limit?"
- "Compare shipping options for this box (10x6x4, 2 pounds) from 10001 to 94105 and generate the cheapest label with delivery in 3 days"
