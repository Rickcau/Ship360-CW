import { useState, useEffect } from 'react'
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Label } from "@/components/ui/label"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Checkbox } from "@/components/ui/checkbox"
import { FormSection } from '@/components/form-section'
import { Action, ActionData } from '@/types/actions'
import { Calendar } from "@/components/ui/calendar"
import { format } from "date-fns"
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover"
import { CalendarIcon } from "lucide-react"
import { cn } from "@/lib/utils"

interface ActionParametersDialogProps {
  action: Action;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSubmit: (action: Action, data: ActionData) => void;
}

export function ActionParametersDialog({ 
  action, 
  open, 
  onOpenChange,
  onSubmit 
}: ActionParametersDialogProps) {
  const [formData, setFormData] = useState<ActionData>({})
  const [isFormValid, setIsFormValid] = useState(false)

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    onSubmit(action, formData)
    onOpenChange(false)
    setFormData({}) // Reset form
  }

  // Format date input as MM/DD/YYYY
  const formatDateInput = (value: string) => {
    // Remove any non-digit characters
    let digits = value.replace(/\D/g, '')
    
    // Don't allow more than 8 digits (MM/DD/YYYY)
    digits = digits.slice(0, 8)
    
    // Format as MM/DD/YYYY
    if (digits.length > 4) {
      return `${digits.slice(0, 2)}/${digits.slice(2, 4)}/${digits.slice(4)}`
    } else if (digits.length > 2) {
      return `${digits.slice(0, 2)}/${digits.slice(2)}`
    } else {
      return digits
    }
  }

  // Validate date in MM/DD/YYYY format
  const validateDate = (dateString: string) => {
    // Check format
    const datePattern = /^(0[1-9]|1[0-2])\/(0[1-9]|[12][0-9]|3[01])\/\d{4}$/
    if (!datePattern.test(dateString)) {
      return false
    }
    
    // Parse date parts
    const parts = dateString.split('/')
    const month = parseInt(parts[0], 10)
    const day = parseInt(parts[1], 10)
    const year = parseInt(parts[2], 10)
    
    // Check year range
    if (year < 2000 || year > 2100) {
      return false
    }
    
    // Create date object and check if valid
    const date = new Date(year, month - 1, day)
    return (
      date.getFullYear() === year &&
      date.getMonth() === month - 1 &&
      date.getDate() === day
    )
  }

  // Validate form whenever formData changes
  useEffect(() => {
    // Check if all required fields are filled
    const requiredParams = action.parameters?.filter(param => param.required) || []
    const allRequiredFieldsFilled = requiredParams.every(param => {
      // For checkbox type, it's considered filled if it has any value
      if (param.name === 'cheapestCarrier') {
        return formData[param.name] !== undefined
      }
      // For deliveryDate field, validate the date format
      if (param.name === 'deliveryDate' && formData[param.name]) {
        // Check if date is fully entered (MM/DD/YYYY) and valid
        return formData[param.name].length === 10 && validateDate(formData[param.name])
      }
      // For all other fields, they must have a non-empty value
      return formData[param.name] !== undefined && formData[param.name] !== ''
    })
    
    setIsFormValid(allRequiredFieldsFilled)
  }, [formData, action.parameters])

  // Generate day options for delivery speed
  const deliveryDayOptions = Array.from({ length: 14 }, (_, i) => i + 1);

  // Group parameters by section for Rate Shop action
  const getGroupedParameters = () => {
    if (action.id === 'rate-shop') {
      const packageDetails = action.parameters?.filter(p => 
        ['weightValue', 'weightUnit', 'length', 'width', 'height', 'dimensionUnit'].includes(p.name)
      ) || [];
      
      const originAddress = action.parameters?.filter(p => 
        ['fromAddress', 'fromCity', 'fromState', 'fromZip'].includes(p.name)
      ) || [];
      
      const destinationAddress = action.parameters?.filter(p => 
        ['toAddress', 'toCity', 'toState', 'toZip'].includes(p.name)
      ) || [];
      
      const otherParams = action.parameters?.filter(p => 
        !packageDetails.includes(p) && 
        !originAddress.includes(p) && 
        !destinationAddress.includes(p)
      ) || [];
      
      return {
        packageDetails,
        originAddress,
        destinationAddress,
        otherParams
      };
    }
    
    return { otherParams: action.parameters || [] };
  };

  const groupedParams = getGroupedParameters();

  // Render a form field based on parameter type
  const renderFormField = (param: any) => {
    // For delivery date parameter, show a date input with MM/DD/YYYY masking
    if (param.name === 'deliveryDate') {
      return (
        <div key={param.name} className="space-y-2">
          <Label htmlFor={param.name}>{param.label}</Label>
          <Input
            id={param.name}
            placeholder="MM/DD/YYYY"
            value={formData[param.name] || ''}
            onChange={(e) => {
              const formattedValue = formatDateInput(e.target.value)
              setFormData(prev => ({
                ...prev,
                [param.name]: formattedValue
              }))
            }}
            required={param.required}
            className={formData[param.name]?.length === 10 && !validateDate(formData[param.name]) ? "border-red-500" : ""}
          />
          {formData[param.name]?.length === 10 && !validateDate(formData[param.name]) && (
            <p className="text-xs text-red-500 mt-1">Please enter a valid date in MM/DD/YYYY format</p>
          )}
        </div>
      );
    }
    // For delivery speed parameter, show a select dropdown
    else if (param.name === 'deliverySpeed') {
      return (
        <div key={param.name} className="space-y-2">
          <Label htmlFor={param.name}>{param.label}</Label>
          <Select 
            value={formData[param.name] || ''}
            onValueChange={(value) => 
              setFormData(prev => ({
                ...prev,
                [param.name]: value
              }))
            }
            required={param.required}
          >
            <SelectTrigger id={param.name}>
              <SelectValue placeholder={param.placeholder} />
            </SelectTrigger>
            <SelectContent>
              {deliveryDayOptions.map(day => (
                <SelectItem key={day} value={day.toString()}>
                  {day} {day === 1 ? 'day' : 'days'}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      );
    } 
    // For parameters with a select type, show a select dropdown with provided options
    else if (param.type === 'select' && param.options) {
      return (
        <div key={param.name} className="space-y-2">
          <Label htmlFor={param.name}>{param.label}</Label>
          <Select 
            value={formData[param.name] || ''}
            onValueChange={(value) => 
              setFormData(prev => ({
                ...prev,
                [param.name]: value
              }))
            }
            required={param.required}
          >
            <SelectTrigger id={param.name}>
              <SelectValue placeholder={param.placeholder} />
            </SelectTrigger>
            <SelectContent>
              {param.options.map((option: any) => (
                <SelectItem key={option.value} value={option.value}>
                  {option.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      );
    }
    // For cheapest carrier parameter, show a checkbox
    else if (param.name === 'cheapestCarrier') {
      return (
        <div key={param.name} className="flex items-center space-x-2">
          <Checkbox 
            id={param.name} 
            checked={formData[param.name] === 'true'}
            onCheckedChange={(checked) => 
              setFormData(prev => ({
                ...prev,
                [param.name]: checked ? 'true' : 'false'
              }))
            }
          />
          <Label htmlFor={param.name} className="cursor-pointer">
            {param.label}
          </Label>
        </div>
      );
    }
    // Default to standard input field for other parameters
    return (
      <div key={param.name} className="space-y-2">
        <Label htmlFor={param.name}>{param.label}</Label>
        <Input
          id={param.name}
          placeholder={param.placeholder}
          value={formData[param.name] || ''}
          onChange={(e) => 
            setFormData(prev => ({
              ...prev,
              [param.name]: e.target.value
            }))
          }
          required={param.required}
        />
      </div>
    );
  };

  return (
    <Dialog open={open} onOpenChange={(isOpen) => {
      if (!isOpen) {
        setFormData({}) // Clear form when dialog closes
        setIsFormValid(false) // Reset form validation
      }
      onOpenChange(isOpen)
    }}>
      <DialogContent className="max-w-lg max-h-[80vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{action.label} Parameters</DialogTitle>
        </DialogHeader>
        <form onSubmit={handleSubmit} className="space-y-4 mt-4">
          {action.id === 'rate-shop' ? (
            <>
              {/* Package Details Section */}
              <FormSection title="Package Details" defaultOpen={true}>
                {groupedParams.packageDetails.map(renderFormField)}
              </FormSection>
              
              {/* Origin Address Section */}
              <FormSection title="Origin Address">
                {groupedParams.originAddress.map(renderFormField)}
              </FormSection>
              
              {/* Destination Address Section */}
              <FormSection title="Destination Address">
                {groupedParams.destinationAddress.map(renderFormField)}
              </FormSection>
              
              {/* Other Parameters */}
              {groupedParams.otherParams.length > 0 && (
                <FormSection title="Additional Options" defaultOpen={true}>
                  {groupedParams.otherParams.map(renderFormField)}
                </FormSection>
              )}
            </>
          ) : (
            // Standard view for other actions
            <>
              {action.parameters?.map(renderFormField)}
            </>
          )}
          
          <div className="flex justify-end gap-2">
            <Button 
              type="button" 
              variant="outline" 
              onClick={() => {
                setFormData({})
                setIsFormValid(false)
                onOpenChange(false)
              }}
            >
              Cancel
            </Button>
            <Button type="submit" disabled={!isFormValid}>
              Submit
            </Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  )
} 