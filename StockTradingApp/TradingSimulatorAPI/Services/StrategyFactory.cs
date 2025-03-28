using Microsoft.Extensions.DependencyInjection;
using System;
using System.Collections.Generic;
using System.Linq;
using TradingSimulatorAPI.Models;

namespace TradingSimulatorAPI.Services;

/// <summary>
/// Provides instances of registered trading strategies.
/// </summary>
public class StrategyFactory
{
    private readonly IServiceProvider _serviceProvider;
    private readonly Dictionary<string, Type> _strategyRegistry = new();
    private readonly List<StrategyInfo> _strategyInfos = new();

    // Use constructor injection to get access to the DI container
    public StrategyFactory(IServiceProvider serviceProvider)
    {
        _serviceProvider = serviceProvider;
        RegisterStrategies();
    }

    private void RegisterStrategies()
    {
        // Manually register strategies or use reflection (more complex)
        // For manual registration, ensure the concrete strategy classes are registered in Program.cs
        RegisterStrategy<SmaCrossoverStrategy>();
        RegisterStrategy<RsiStrategy>();
        // Add more strategies here
    }

    private void RegisterStrategy<TStrategy>() where TStrategy : IStrategy
    {
         // We need an instance to get the Name and Info, resolved via DI
         // Use GetRequiredService to ensure the strategy is registered in DI container
         try
         {
             using var scope = _serviceProvider.CreateScope(); // Resolve within a scope
             var strategyInstance = scope.ServiceProvider.GetRequiredService<TStrategy>();
             var strategyName = strategyInstance.Name;

             if (_strategyRegistry.ContainsKey(strategyName))
             {
                 // Log warning or throw exception if duplicate name found
                 Console.WriteLine($"Warning: Duplicate strategy name '{strategyName}' detected during registration.");
                 return;
             }
            _strategyRegistry.Add(strategyName, typeof(TStrategy));
            _strategyInfos.Add(strategyInstance.Info); // Store info for listing later

         }
         catch (Exception ex)
         {
              Console.WriteLine($"Error registering strategy {typeof(TStrategy).Name}: {ex.Message}");
              // Decide how to handle registration errors (log, throw, etc.)
         }

    }


    /// <summary>
    /// Gets an instance of the strategy with the specified name.
    /// </summary>
    /// <param name="name">The unique name identifier of the strategy.</param>
    /// <returns>An instance of IStrategy.</returns>
    /// <exception cref="ArgumentException">Thrown if the strategy name is not found.</exception>
    public IStrategy GetStrategy(string name)
    {
        if (_strategyRegistry.TryGetValue(name, out Type? strategyType))
        {
            // Resolve the strategy instance using the DI container
            // This ensures any dependencies the strategy has are also injected
            try
            {
                 // Use GetRequiredService as we expect it to be registered if it's in the registry
                 // Resolve within a scope if the strategy has scoped dependencies
                 // Or directly if it's transient or singleton and has no scoped dependencies
                 // return (IStrategy)_serviceProvider.GetRequiredService(strategyType);

                 // Safer approach: Resolve within a temporary scope if unsure about dependency lifetimes
                  using var scope = _serviceProvider.CreateScope();
                  return (IStrategy)scope.ServiceProvider.GetRequiredService(strategyType);
            }
            catch (Exception ex)
            {
                 Console.WriteLine($"Error resolving strategy '{name}' from DI container: {ex.Message}");
                 throw new InvalidOperationException($"Could not resolve strategy '{name}'. Ensure it and its dependencies are registered correctly.", ex);
            }

        }
        throw new ArgumentException($"Strategy with name '{name}' not found.", nameof(name));
    }

    /// <summary>
    /// Gets information about all registered strategies.
    /// </summary>
    /// <returns>A list of StrategyInfo objects.</returns>
    public IEnumerable<StrategyInfo> GetAllStrategyInfos()
    {
        return _strategyInfos.OrderBy(info => info.DisplayName);
    }
}
