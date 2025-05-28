"use client"

import { useState } from 'react'
import { ChevronDown, ChevronRight } from 'lucide-react'
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from './ui/collapsible'

interface FormSectionProps {
  title: string;
  defaultOpen?: boolean;
  children: React.ReactNode;
}

export function FormSection({ title, defaultOpen = false, children }: FormSectionProps) {
  const [isOpen, setIsOpen] = useState(defaultOpen)

  return (
    <Collapsible
      open={isOpen}
      onOpenChange={setIsOpen}
      className="w-full border rounded-md mb-4"
    >
      <CollapsibleTrigger className="flex items-center justify-between w-full p-3 text-left font-medium border-b bg-muted/30">
        <div className="flex items-center gap-2">
          {isOpen ? <ChevronDown className="h-4 w-4" /> : <ChevronRight className="h-4 w-4" />}
          <span>{title}</span>
        </div>
      </CollapsibleTrigger>
      <CollapsibleContent>
        <div className="p-3 space-y-4">
          {children}
        </div>
      </CollapsibleContent>
    </Collapsible>
  )
} 