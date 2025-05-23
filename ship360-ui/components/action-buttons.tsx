import { useState } from 'react'
import { Button } from "@/components/ui/button"
import { ActionParametersDialog } from "@/components/action-parameters-dialog"
import { RecentActions } from "@/components/recent-actions"
import { cn } from "@/lib/utils"
import {
  PlayCircle,
  StopCircle,
  ListChecks,
  RefreshCw,
  DollarSign
} from "lucide-react"
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip"
import { Action, ActionData } from "@/types/actions"

interface ActionButtonsProps {
  onAction: (prompt: string) => void
}

export function ActionButtons({ onAction }: ActionButtonsProps) {
  const [selectedAction, setSelectedAction] = useState<Action | null>(null)
  const [dialogOpen, setDialogOpen] = useState(false)
  const [recentActionsKey, setRecentActionsKey] = useState(0)

  const saveToRecents = (action: Action, data?: ActionData) => {
    const recentActions = JSON.parse(localStorage.getItem('recentActions') || '[]')
    const newAction = {
      id: action.id,
      label: action.label,
      timestamp: Date.now(),
      className: action.className,
      promptTemplate: data 
        ? action.promptTemplate
            // Create Label for Order parameters
            .replace('{orderNumber}', data.orderNumber || '')
            .replace('{deliverySpeed}', data.deliverySpeed || '')
            .replace('{cheapestCarrierText}', data.cheapestCarrier === 'true' ? ' using the cheapest carrier' : '')
            .replace('{deliveryDateText}', data.deliveryDate ? ` with delivery by ${data.deliveryDate}` : '')
            
            // Generate Label parameters
            .replace('{carrierService}', data.carrierService || '')
            
            // Rate Shop parameters - Weight & Dimensions
            .replace('{weightValue}', data.weightValue || '')
            .replace('{weightUnit}', data.weightUnit || '')
            .replace('{length}', data.length || '')
            .replace('{width}', data.width || '')
            .replace('{height}', data.height || '')
            .replace('{dimensionUnit}', data.dimensionUnit || '')
            
            // Rate Shop parameters - Origin Address
            .replace('{fromAddress}', data.fromAddress || '')
            .replace('{fromCity}', data.fromCity || '')
            .replace('{fromState}', data.fromState || '')
            .replace('{fromZip}', data.fromZip || '')
            
            // Rate Shop parameters - Destination Address
            .replace('{toAddress}', data.toAddress || '')
            .replace('{toCity}', data.toCity || '')
            .replace('{toState}', data.toState || '')
            .replace('{toZip}', data.toZip || '')
            
            // Rate Shop parameters - Country
            .replace('{countryCode}', data.countryCode || '')
            
            // Legacy parameters
            .replace('{weight}', data.weight || '')
            .replace('{dimensions}', data.dimensions || '')
            .replace('{vmName}', data.vmName || '')
            .replace('{resourceGroup}', data.resourceGroup || '')
        : action.promptTemplate,
      ...(data && { 
        // Create Label for Order parameters
        orderNumber: data.orderNumber,
        deliverySpeed: data.deliverySpeed,
        cheapestCarrier: data.cheapestCarrier,
        deliveryDate: data.deliveryDate,
        
        // Generate Label parameters
        carrierService: data.carrierService,
        
        // Rate Shop parameters
        weightValue: data.weightValue,
        weightUnit: data.weightUnit,
        length: data.length,
        width: data.width,
        height: data.height,
        dimensionUnit: data.dimensionUnit,
        fromAddress: data.fromAddress,
        fromCity: data.fromCity,
        fromState: data.fromState,
        fromZip: data.fromZip,
        toAddress: data.toAddress,
        toCity: data.toCity,
        toState: data.toState,
        toZip: data.toZip,
        countryCode: data.countryCode,
        
        // Legacy parameters
        weight: data.weight,
        dimensions: data.dimensions,
        vmName: data.vmName, 
        resourceGroup: data.resourceGroup 
      })
    }

    // Add to start, remove duplicates, keep only last 10
    const updatedActions = [
      newAction,
      ...recentActions.filter((a: typeof newAction) => 
        a.id !== action.id || 
        (data?.orderNumber && a.orderNumber !== data.orderNumber) ||
        (data?.weightValue && a.weightValue !== data.weightValue) ||
        (data?.fromZip && a.fromZip !== data.fromZip) || 
        (data?.toZip && a.toZip !== data.toZip) ||
        (data?.vmName && a.vmName !== data.vmName) || 
        (data?.resourceGroup && a.resourceGroup !== data.resourceGroup)
      )
    ].slice(0, 10)

    localStorage.setItem('recentActions', JSON.stringify(updatedActions))
    setRecentActionsKey(prev => prev + 1) // Force RecentActions to re-render
  }

  const actions: Action[] = [
    { 
      id: 'create-label',
      label: "Create Label for Order", 
      value: "create-label", 
      className: "bg-green-500 hover:bg-green-600 dark:bg-green-600 dark:hover:bg-green-700 text-white",
      requiresParameters: true,
      icon: PlayCircle,
      tooltip: "Create a shipping label for a specific order",
      parameters: [
        {
          name: 'orderNumber',
          label: 'Order Number',
          placeholder: 'Enter order number',
          required: true
        },
        {
          name: 'deliverySpeed',
          label: 'Delivery Speed (days)',
          placeholder: 'Select delivery speed',
          required: true
        },
        {
          name: 'cheapestCarrier',
          label: 'Use cheapest carrier',
          placeholder: 'Check for cheapest option',
          required: false
        }
      ],
      promptTemplate: 'Create a shipping label for order {orderNumber} with delivery in {deliverySpeed} days{cheapestCarrierText}'
    },
    { 
      id: 'rate-shop',
      label: "Rate Shop", 
      value: "rate-shop", 
      className: "bg-red-500 hover:bg-red-600 dark:bg-red-600 dark:hover:bg-red-700 text-white",
      requiresParameters: true,
      icon: DollarSign,
      tooltip: "Compare shipping rates for a package",
      parameters: [
        // Package Weight
        {
          name: 'weightValue',
          label: 'Package Weight',
          placeholder: 'Enter package weight',
          required: true
        },
        {
          name: 'weightUnit',
          label: 'Weight Unit',
          placeholder: 'Select weight unit',
          required: true,
          type: 'select',
          options: [
            { value: 'lb', label: 'Pounds (lb)' },
            { value: 'kg', label: 'Kilograms (kg)' },
            { value: 'oz', label: 'Ounces (oz)' }
          ]
        },
        // Package Dimensions
        {
          name: 'length',
          label: 'Length',
          placeholder: 'Enter length',
          required: true
        },
        {
          name: 'width',
          label: 'Width',
          placeholder: 'Enter width',
          required: true
        },
        {
          name: 'height',
          label: 'Height',
          placeholder: 'Enter height',
          required: true
        },
        {
          name: 'dimensionUnit',
          label: 'Dimension Unit',
          placeholder: 'Select dimension unit',
          required: true,
          type: 'select',
          options: [
            { value: 'in', label: 'Inches (in)' },
            { value: 'cm', label: 'Centimeters (cm)' }
          ]
        },
        // Origin Address
        {
          name: 'fromAddress',
          label: 'Origin Address',
          placeholder: 'Enter street address',
          required: true
        },
        {
          name: 'fromCity',
          label: 'Origin City',
          placeholder: 'Enter city',
          required: true
        },
        {
          name: 'fromState',
          label: 'Origin State/Province',
          placeholder: 'Enter state/province',
          required: true
        },
        {
          name: 'fromZip',
          label: 'Origin ZIP/Postal Code',
          placeholder: 'Enter ZIP/postal code',
          required: true
        },
        // Destination Address
        {
          name: 'toAddress',
          label: 'Destination Address',
          placeholder: 'Enter street address',
          required: true
        },
        {
          name: 'toCity',
          label: 'Destination City',
          placeholder: 'Enter city',
          required: true
        },
        {
          name: 'toState',
          label: 'Destination State/Province',
          placeholder: 'Enter state/province',
          required: true
        },
        {
          name: 'toZip',
          label: 'Destination ZIP/Postal Code',
          placeholder: 'Enter ZIP/postal code',
          required: true
        },
        // Country Code
        {
          name: 'countryCode',
          label: 'Country Code',
          placeholder: 'Enter 2-letter country code (e.g., US, CA)',
          required: true,
          type: 'select',
          options: [
            { value: 'US', label: 'United States (US)' },
            { value: 'CA', label: 'Canada (CA)' },
            { value: 'MX', label: 'Mexico (MX)' },
            { value: 'GB', label: 'United Kingdom (GB)' }
          ]
        }
      ],
      promptTemplate: 'Rate shop for a {weightValue} {weightUnit} package with dimensions {length}x{width}x{height} {dimensionUnit}, shipping from {fromAddress}, {fromCity}, {fromState} {fromZip} to {toAddress}, {toCity}, {toState} {toZip} in {countryCode}'
    },
    { 
      id: 'rate-shop-order',
      label: "Rate Shop Order", 
      value: "rate-shop-order", 
      className: "bg-blue-500 hover:bg-blue-600 dark:bg-blue-600 dark:hover:bg-blue-700 text-white",
      requiresParameters: true,
      icon: ListChecks,
      tooltip: "Find shipping rates for an existing order",
      parameters: [
        {
          name: 'orderNumber',
          label: 'Order Number',
          placeholder: 'Enter order number',
          required: true
        },
        {
          name: 'deliveryDate',
          label: 'Delivery Date',
          placeholder: 'Enter delivery date',
          required: true
        }
      ],
      promptTemplate: 'Can you rate shop for order {orderNumber}{deliveryDateText}'
    },
    { 
      id: 'generate-label',
      label: "Generate Label", 
      value: "generate-label", 
      className: "bg-orange-500 hover:bg-orange-600 dark:bg-orange-600 dark:hover:bg-orange-700 text-white",
      requiresParameters: true,
      icon: RefreshCw,
      tooltip: "Generate a shipping label for a package",
      parameters: [
        {
          name: 'orderNumber',
          label: 'Order Number',
          placeholder: 'Enter order number',
          required: true
        },
        {
          name: 'carrierService',
          label: 'Carrier Service',
          placeholder: 'Select carrier service',
          required: true,
          type: 'select',
          options: [
            { value: 'ups-ground', label: 'UPS Ground' },
            { value: 'ups-2day', label: 'UPS 2nd Day Air' },
            { value: 'ups-overnight', label: 'UPS Next Day Air' },
            { value: 'fedex-ground', label: 'FedEx Ground' },
            { value: 'fedex-2day', label: 'FedEx 2Day' },
            { value: 'fedex-overnight', label: 'FedEx Priority Overnight' },
            { value: 'usps-ground', label: 'USPS Ground Advantage' },
            { value: 'usps-priority', label: 'USPS Priority Mail' },
            { value: 'usps-express', label: 'USPS Priority Mail Express' }
          ]
        }
      ],
      promptTemplate: 'Generate a shipping label for order {orderNumber} using {carrierService}'
    }
  ]

  const handleActionClick = (action: Action) => {
    if (action.requiresParameters) {
      setSelectedAction(action)
      setDialogOpen(true)
    } else {
      onAction(action.promptTemplate)
      saveToRecents(action)
    }
  }

  const handleParameterSubmit = (action: Action, data: ActionData) => {
    let prompt = action.promptTemplate
    
    if (data.orderNumber) {
      prompt = prompt.replace('{orderNumber}', data.orderNumber)
    }
    if (data.deliverySpeed) {
      prompt = prompt.replace('{deliverySpeed}', data.deliverySpeed)
    }
    // Handle the cheapest carrier checkbox
    prompt = prompt.replace('{cheapestCarrierText}', 
      data.cheapestCarrier === 'true' ? ' using the cheapest carrier' : '')
    
    // Handle delivery date text
    prompt = prompt.replace('{deliveryDateText}', 
      data.deliveryDate ? ` with delivery by ${data.deliveryDate}` : '')
    
    // Handle Rate Shop parameters
    if (data.weightValue) {
      prompt = prompt.replace('{weightValue}', data.weightValue)
    }
    if (data.weightUnit) {
      prompt = prompt.replace('{weightUnit}', data.weightUnit)
    }
    if (data.length) {
      prompt = prompt.replace('{length}', data.length)
    }
    if (data.width) {
      prompt = prompt.replace('{width}', data.width)
    }
    if (data.height) {
      prompt = prompt.replace('{height}', data.height)
    }
    if (data.dimensionUnit) {
      prompt = prompt.replace('{dimensionUnit}', data.dimensionUnit)
    }
    if (data.fromAddress) {
      prompt = prompt.replace('{fromAddress}', data.fromAddress)
    }
    if (data.fromCity) {
      prompt = prompt.replace('{fromCity}', data.fromCity)
    }
    if (data.fromState) {
      prompt = prompt.replace('{fromState}', data.fromState)
    }
    if (data.fromZip) {
      prompt = prompt.replace('{fromZip}', data.fromZip)
    }
    if (data.toAddress) {
      prompt = prompt.replace('{toAddress}', data.toAddress)
    }
    if (data.toCity) {
      prompt = prompt.replace('{toCity}', data.toCity)
    }
    if (data.toState) {
      prompt = prompt.replace('{toState}', data.toState)
    }
    if (data.toZip) {
      prompt = prompt.replace('{toZip}', data.toZip)
    }
    if (data.countryCode) {
      prompt = prompt.replace('{countryCode}', data.countryCode)
    }
    
    if (data.vmName) {
      prompt = prompt.replace('{vmName}', data.vmName)
    }
    if (data.resourceGroup) {
      prompt = prompt.replace('{resourceGroup}', data.resourceGroup)
    }
    
    // Generate Label parameters
    if (data.carrierService) {
      prompt = prompt.replace('{carrierService}', data.carrierService)
    }
    
    onAction(prompt)
    saveToRecents(action, data)
  }

  return (
    <>
      <div className="flex flex-col">
        <div className="flex flex-wrap gap-1.5 justify-center py-3 border-t">
          <TooltipProvider>
            {actions.map((action) => {
              const Icon = action.icon
              return (
                <Tooltip key={action.id}>
                  <TooltipTrigger asChild>
                    <Button
                      onClick={() => handleActionClick(action)}
                      className={cn(
                        "h-7 px-2.5 text-xs font-medium gap-1.5",
                        action.className
                      )}
                    >
                      <Icon size={14} />
                      {action.label}
                    </Button>
                  </TooltipTrigger>
                  <TooltipContent>
                    <p>{action.tooltip}</p>
                  </TooltipContent>
                </Tooltip>
              )
            })}
          </TooltipProvider>
        </div>

        <RecentActions 
          key={recentActionsKey}
          onActionClick={onAction}
          onClear={() => setRecentActionsKey(prev => prev + 1)}
        />
      </div>

      {selectedAction && (
        <ActionParametersDialog
          action={selectedAction}
          open={dialogOpen}
          onOpenChange={setDialogOpen}
          onSubmit={handleParameterSubmit}
        />
      )}
    </>
  )
}

