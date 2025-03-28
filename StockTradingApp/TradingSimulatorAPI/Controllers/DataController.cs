using Microsoft.AspNetCore.Mvc;
using TradingSimulatorAPI.Models;
using TradingSimulatorAPI.Services;
using System.Collections.Generic;
using System.Linq;

namespace TradingSimulatorAPI.Controllers;

[ApiController]
[Route("api/[controller]")]
public class DataController : ControllerBase
{
    private readonly StrategyFactory _strategyFactory;

    public DataController(StrategyFactory strategyFactory)
    {
        _strategyFactory = strategyFactory;
    }

    /// <summary>
    /// Gets a list of available trading strategies.
    /// </summary>
    /// <returns>A list of StrategyInfo objects.</returns>
    [HttpGet("strategies")]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IEnumerable<StrategyInfo>))]
    public ActionResult<IEnumerable<StrategyInfo>> GetAvailableStrategies()
    {
        var strategies = _strategyFactory.GetAllStrategyInfos();
        return Ok(strategies);
    }

    // Add other data-related endpoints if needed (e.g., list available tickers - though this is complex)
}
