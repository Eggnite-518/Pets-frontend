interface StepIndicatorProps {
  currentStep: number
  totalSteps: number
  stepTitle: string
}

export function StepIndicator({ currentStep, totalSteps, stepTitle }: StepIndicatorProps) {
  return (
    <div className="px-5 pt-6 pb-4">
      <div className="flex items-center justify-between mb-1">
        <span className="text-xs font-medium text-primary tracking-wider">
          STEP {currentStep < 10 ? `0${currentStep}` : currentStep}
        </span>
        <span className="text-sm text-muted-foreground">
          {currentStep}/{totalSteps}
        </span>
      </div>
      <h2 className="text-2xl font-semibold text-foreground mb-4">{stepTitle}</h2>
      <div className="flex gap-2">
        {Array.from({ length: totalSteps }).map((_, index) => (
          <div
            key={index}
            className={`h-1 flex-1 rounded-full transition-colors ${
              index < currentStep ? 'bg-primary' : 'bg-border'
            }`}
          />
        ))}
      </div>
    </div>
  )
}
