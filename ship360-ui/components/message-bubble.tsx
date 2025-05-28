import { MessageRole } from '@/types/chat'
import { cn } from "@/lib/utils"

interface MessageBubbleProps {
  content: string
  role: MessageRole
}

export function MessageBubble({ content, role }: MessageBubbleProps) {
  // Process content to replace escaped newlines with actual newlines and format shipping options
  const processContent = (text: string): string => {
    // Replace escaped newlines with actual newlines
    let processed = text.replace(/\\n/g, '\n').trim();
    
    // Check if this is a shipping options response
    if (processed.includes('shipping options') && processed.includes('**Carrier**:')) {
      try {
        // Split into sections - intro and options
        const parts = processed.split(/\n\d+\./);
        
        if (parts.length > 1) {
          // Format the intro
          let result = parts[0].trim() + '\n\n';
          
          // Format each shipping option
          for (let i = 1; i < parts.length; i++) {
            let option = parts[i].trim();
            
            // Check for the "I can show you more options" text in the last option
            if (i === parts.length - 1 && option.includes("I can show you more options")) {
              const optionParts = option.split(/I can show you/);
              option = optionParts[0].trim();
              
              result += `<div class="shipping-option">
                <div class="shipping-option-title">Option ${i}</div>
                ${option.replace(/\*\*([^*]+)\*\*/g, '<span class="highlight">$1</span>')}
              </div>`;
              
              // Add the follow-up text outside the shipping option card
              result += `<div class="mt-4">I can show you${optionParts[1]}</div>`;
            } else {
              result += `<div class="shipping-option">
                <div class="shipping-option-title">Option ${i}</div>
                ${option.replace(/\*\*([^*]+)\*\*/g, '<span class="highlight">$1</span>')}
              </div>`;
            }
          }
          
          return result;
        }
      } catch (error) {
        console.error("Error formatting shipping options:", error);
        // Fall back to basic formatting
      }
    }
    
    return processed;
  };

  const processedContent = processContent(content);
  const isHTML = processedContent.includes('<div');

  return (
    <div
      className={cn(
        "flex flex-col rounded-lg p-4 mb-2",
        role === 'user' 
          ? "ml-auto mr-1 bg-primary text-primary-foreground max-w-[80%]"
          : role === 'assistant'
          ? "mr-auto ml-1 bg-secondary text-secondary-foreground max-w-[80%]"
          : "mr-auto ml-1 bg-accent text-accent-foreground max-w-[80%]"
      )}
    >
      {role !== 'user' && (
        <div className="font-semibold mb-2">
          {role === 'assistant' ? 'Assistant' : 'IT Specialist'}
        </div>
      )}
      {isHTML ? (
        <div 
          className="chat-formatted-response" 
          dangerouslySetInnerHTML={{ __html: processedContent }}
        />
      ) : (
        <div className="whitespace-pre-wrap leading-relaxed chat-formatted-response">
          {processedContent}
        </div>
      )}
    </div>
  )
}

