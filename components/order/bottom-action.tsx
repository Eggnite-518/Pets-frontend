'use client'

import { ArrowRight } from 'lucide-react'
import { Button } from '@/components/ui/button'

interface BottomActionProps {
  primaryLabel: string
  onPrimaryClick: () => void
  secondaryLabel?: string
  onSecondaryClick?: () => void
  showSecondary?: boolean
  disabled?: boolean
}

export function BottomAction({
  primaryLabel,
  onPrimaryClick,
  secondaryLabel = '返回',
  onSecondaryClick,
  showSecondary = false,
  disabled = false
}: BottomActionProps) {
  return (
    <div className="sticky bottom-0 bg-card border-t border-border px-5 py-4 pb-8">
      <div className="flex gap-3">
        {showSecondary && (
          <Button
            variant="outline"
            className="flex-shrink-0 rounded-full px-6 h-12 text-sm font-medium"
            onClick={onSecondaryClick}
          >
            {secondaryLabel}
          </Button>
        )}
        <Button
          className="flex-1 rounded-full h-12 text-sm font-medium bg-primary hover:bg-primary/90 text-primary-foreground gap-2"
          onClick={onPrimaryClick}
          disabled={disabled}
        >
          {primaryLabel}
          <ArrowRight className="w-4 h-4" />
        </Button>
      </div>
    </div>
  )
}
