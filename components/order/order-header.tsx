'use client'

import { ArrowLeft, HelpCircle } from 'lucide-react'
import { useRouter } from 'next/navigation'

interface OrderHeaderProps {
  title?: string
  onBack?: () => void
}

export function OrderHeader({ title = '发布订单', onBack }: OrderHeaderProps) {
  const router = useRouter()

  const handleBack = () => {
    if (onBack) {
      onBack()
    } else {
      router.back()
    }
  }

  return (
    <header className="sticky top-0 z-50 flex items-center justify-between px-4 py-3 bg-card">
      <button
        onClick={handleBack}
        className="p-2 -ml-2 text-foreground hover:bg-secondary rounded-full transition-colors"
        aria-label="返回"
      >
        <ArrowLeft className="w-5 h-5" />
      </button>
      <h1 className="text-base font-medium text-foreground">{title}</h1>
      <button
        className="p-2 -mr-2 text-muted-foreground hover:bg-secondary rounded-full transition-colors"
        aria-label="帮助"
      >
        <HelpCircle className="w-5 h-5" />
      </button>
    </header>
  )
}
