USE supplychaindb;


CREATE TABLE orderList(
	orderId INT NOT NULL,
	orderDate DATE NOT NULL,
	originPort VARCHAR(20) NOT NULL,
	carrier VARCHAR(20) NOT NULL,
	TPT INT NOT NULL,
	serviceLevel VARCHAR(20) NOT NULL,
    shipAheadDayCount INT NOT NULL, 
	shipLateDayCount INT NOT NULL, 
	customer VARCHAR(20) NOT NULL,
	productId INT NOT NULL,
	plantCode VARCHAR(20) NOT NULL,
	destinationPort	 VARCHAR(20) NOT NULL,
    unitQuantity INT NOT NULL,
	weight DECIMAL(6,2) NOT NULL, 
	PRIMARY KEY(orderId)
);

LOAD DATA LOCAL INFILE 'C:/Users/billy/OneDrive/Desktop/New Dataset/supplychaindataset/Supply chain logisitcs problem.csv'
INTO TABLE orderList
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 LINES;


CREATE TABLE freightRates (
	carrier VARCHAR(20) NOT NULL,
	origPortCd VARCHAR(20) NOT NULL,
	destPortCd VARCHAR(20) NOT NULL,
	minWghQty DECIMAL(12,8) NOT NULL,
	maxWghQty DECIMAL(12,8) NOT NULL,
	svcCd VARCHAR(20) NOT NULL,
	minimumCost DECIMAL(8,2) NOT NULL,
	rate DECIMAL(8,2) NOT NULL,	
    modeDsc VARCHAR(20) NOT NULL,
	tptDayCnt INT NOT NULL,
    carrierType VARCHAR(20) NOT NULL
);

LOAD DATA LOCAL INFILE 'C:/Users/billy/OneDrive/Desktop/New Dataset/supplychaindataset/Supply chain logisitcs problem2.csv'
INTO TABLE freightRates
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

CREATE TABLE whCosts(
	WH VARCHAR(20),
    costsUnit DECIMAL(8,2));
    
LOAD DATA LOCAL INFILE 'C:/Users/billy/OneDrive/Desktop/New Dataset/supplychaindataset/Supply chain logisitcs WHCOSTS.csv'
INTO TABLE whCosts
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

CREATE TABLE whCapacities (
	plantId VARCHAR(20) NOT NULL,
    dailyCapacity INT NOT NULL
);

LOAD DATA LOCAL INFILE 'C:/Users/billy/OneDrive/Desktop/New Dataset/supplychaindataset/Supply chain logisitcs WHCapacities.csv'
INTO TABLE whCapacities
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

CREATE TABLE productsPerPlant(
	plantCode VARCHAR(20) NOT NULL,
    productId INT NOT NULL
);

LOAD DATA LOCAL INFILE 'C:/Users/billy/OneDrive/Desktop/New Dataset/supplychaindataset/Supply chain logisitcs productsperplant.csv'
INTO TABLE productsPerPlant
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

CREATE TABLE vmiCustomers (
	plantCode VARCHAR(20) NOT NULL,
    customers VARCHAR(50) NOT NULL
);

LOAD DATA LOCAL INFILE 'C:/Users/billy/OneDrive/Desktop/New Dataset/supplychaindataset/Supply chain logisitcs VMICustomers.csv'
INTO TABLE vmiCustomers
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

CREATE TABLE plantPorts (
	plantCode VARCHAR(20) NOT NULL,
    `port` VARCHAR(20) NOT NULL
);

LOAD DATA LOCAL INFILE 'C:/Users/billy/OneDrive/Desktop/New Dataset/supplychaindataset/Supply chain logisitcs plantPorts.csv'
INTO TABLE plantPorts
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- TRANSPORTATION PERFORMANCE
-- 1. Which carriers have the highest late shipment counts?
SELECT 
    carrier,
    COUNT(orderId) AS totalOrdersHandled,
    SUM(CASE WHEN shipLateDayCount > 0 THEN 1 ELSE 0 END) AS totalLateShipments,
    ROUND(
        (SUM(CASE WHEN shipLateDayCount > 0 THEN 1 ELSE 0 END) / COUNT(orderId)) * 100, 
        2
    ) AS lateShipmentRatePercentage,
    ROUND(AVG(shipLateDayCount), 1) AS avgDaysDelayedPerLateOrder
FROM orderList
GROUP BY carrier
ORDER BY totalLateShipments DESC;

-- 2. Which routes have the longest transportation times?
SELECT 
    originPort,
    destinationPort,
    COUNT(orderId) AS totalOrdersShipped,
    ROUND(AVG(TPT), 1) AS avgBaseTransitDays,
    ROUND(AVG(shipLateDayCount), 1) AS avgDaysDelayed,
    ROUND(AVG(TPT + shipLateDayCount), 1) AS totalActualTransitTime
FROM orderList
GROUP BY originPort, destinationPort
HAVING totalOrdersShipped >= 5 
ORDER BY totalActualTransitTime DESC;


-- 3. Which service levels perform best?
SELECT 
    serviceLevel,
    COUNT(orderId) AS totalOrders,
    SUM(CASE WHEN shipLateDayCount = 0 THEN 1 ELSE 0 END) AS onTimeShipments,
    ROUND((SUM(CASE WHEN shipLateDayCount = 0 THEN 1 ELSE 0 END) / COUNT(orderId)) * 100, 
        2) AS onTimeRatePercentage,
    ROUND(AVG(shipLateDayCount), 1) AS avgDaysDelayed,
    MAX(shipLateDayCount) AS worstCaseDelayDays,
    ROUND(AVG(TPT), 1) AS avgTransitDays
FROM orderList
GROUP BY serviceLevel
ORDER BY onTimeRatePercentage DESC;

-- WAREHOUSE OPTIMIZATION
-- 4. Which warehouses exceed capacity limits?
WITH dailyWarehouseVolume AS (
    SELECT 
        plantCode AS warehouseId,
        orderDate,
        SUM(unitQuantity) AS totalUnitsProcessed
    FROM orderList
    GROUP BY plantCode, orderDate)
SELECT 
    dwv.warehouseId,
    wc.dailyCapacity AS maxCapacity,
    COUNT(CASE WHEN dwv.totalUnitsProcessed > wc.dailyCapacity THEN 1 END) AS daysExceededCount,
    ROUND(AVG(dwv.totalUnitsProcessed), 0) AS avgDailyUnitsProcessed,
    ROUND(MAX(dwv.totalUnitsProcessed), 0) AS peakOneDayVolume
FROM dailyWarehouseVolume dwv
JOIN whCapacities wc 
    ON dwv.warehouseId = wc.plantId
GROUP BY dwv.warehouseId, wc.dailyCapacity
ORDER BY daysExceededCount DESC;
SELECT * FROM orderList;

-- 5.Which plants handle the highest shipment volume?
SELECT 
    plantCode AS plantId,
    COUNT(orderId) AS totalOrdersFulfilled,
    SUM(unitQuantity) AS totalUnitsShipped,
    ROUND(SUM(weight), 2) AS totalWeightShippedKg,
    ROUND(AVG(unitQuantity), 0) AS avgUnitsPerOrder,
    ROUND(AVG(weight), 2) AS avgWeightPerOrder
FROM orderList
GROUP BY plantCode
ORDER BY totalUnitsShipped DESC; 

-- COST OPTIMIZATION
-- 6. Which shipping routes are most expensive?
WITH calculatedOrders AS (
    SELECT 
        o.originPort,
        o.destinationPort,
        o.orderId,
        o.weight,
        CASE 
            WHEN (o.weight * f.rate) < f.minimumCost THEN f.minimumCost
            ELSE (o.weight * f.rate)
        END AS actualFreightCost
    FROM orderList o
    LEFT JOIN freightRates f 
        ON o.carrier = f.carrier
        AND o.originPort = f.origPortCd
        AND o.destinationPort = f.destPortCd
        AND o.serviceLevel = f.svcCd
        AND o.weight >= f.minWghQty
        AND o.weight <= f.maxWghQty
)
SELECT 
    originPort,
    destinationPort,
    COUNT(orderId) AS totalShipments,
    ROUND(SUM(actualFreightCost), 2) AS totalLaneSpend,
    ROUND(AVG(actualFreightCost), 2) AS avgCostPerShipment,
    ROUND(SUM(weight), 2) AS totalWeightMoved
FROM CalculatedOrders
GROUP BY 
	originPort, 
	destinationPort
ORDER BY totalLaneSpend DESC;

-- 7. Which carriers provide best cost-to-service performance?
WITH shipmentCosts AS (
    SELECT 
        o.carrier,
        o.orderId,
        o.shipLateDayCount,
        CASE 
            WHEN (o.weight * f.rate) < f.minimumCost THEN f.minimumCost
            ELSE (o.weight * f.rate)
        END AS freightCost
    FROM orderList o
    LEFT JOIN freightRates f 
        ON o.carrier = f.carrier
        AND o.originPort = f.origPortCd
        AND o.destinationPort = f.destPortCd
        AND o.serviceLevel = f.svcCd
        AND o.weight >= f.minWghQty
        AND o.weight <= f.maxWghQty)
SELECT 
    carrier,
    COUNT(orderId) AS totalOrdersShipped,
    ROUND(SUM(freightCost), 2) AS totalCarrierSpend,
    ROUND(AVG(freightCost), 2) AS avgCostPerOrder,
    SUM(CASE WHEN shipLateDayCount = 0 THEN 1 ELSE 0 END) AS onTimeOrders,
    ROUND((SUM(CASE WHEN shipLateDayCount = 0 THEN 1 ELSE 0 END) / COUNT(orderId)) * 100, 2
    ) AS onTimeRatePercentage,
    ROUND(AVG(shipLateDayCount), 1) AS avgDaysDelayed
FROM ShipmentCosts
GROUP BY carrier
HAVING totalOrdersShipped > 10 
ORDER BY 
	onTimeRatePercentage DESC, 
    avgCostPerOrder ASC;
    
-- CUSTOMER SERVICE ANALYSIS
-- 8. Which customers experience the most delays?
SELECT 
    customer,
    COUNT(orderId) AS totalOrdersPlaced,
    SUM(CASE WHEN shipLateDayCount > 0 THEN 1 ELSE 0 END) AS totalDelayedOrders,
    ROUND(
        (SUM(CASE WHEN shipLateDayCount > 0 THEN 1 ELSE 0 END) / COUNT(orderId)) * 100, 2
    ) AS delayRatePercentage,
    ROUND(AVG(shipLateDayCount), 1) AS avgDaysDelayed,
    MAX(shipLateDayCount) AS longestSingleDelayDays
FROM orderList
GROUP BY customer
HAVING totalOrdersPlaced >= 5 
ORDER BY 
	totalDelayedOrders DESC, 
    delayRatePercentage DESC;
    
-- 9. Which customers generate the highest shipping demand?
SELECT 
    customer,
    COUNT(orderId) AS totalOrdersPlaced,
    SUM(unitQuantity) AS totalUnitsDemanded,
    ROUND(SUM(weight), 2) AS totalWeightDemandedKg,
    ROUND(AVG(unitQuantity), 0) AS avgUnitsPerOrder,
    ROUND(AVG(weight), 2) AS avgWeightPerOrder
FROM orderList
GROUP BY customer
ORDER BY 
	totalUnitsDemanded DESC, 
    totalOrdersPlaced DESC;
   
  -- ROUTE & NETWORK OPTIMIZATION 
-- 10. Which ports are busiest?
WITH busiestPorts AS (
    SELECT 
        originPort AS portCode,
        'Origin' AS portRole,
        COUNT(orderId) AS totalShipmentsHandled,
        SUM(unitQuantity) AS totalUnitsMoved,
        ROUND(SUM(weight), 2) AS totalWeightMovedKg
    FROM orderList
    GROUP BY originPort
    UNION ALL
    SELECT 
        destinationPort AS portCode,
        'Destination' AS portRole,
        COUNT(orderId) AS totalShipmentsHandled,
        SUM(unitQuantity) AS totalUnitsMoved,
        ROUND(SUM(weight), 2) AS totalWeightMovedKg
    FROM orderList
    GROUP BY destinationPort)
SELECT *
FROM busiestPorts
ORDER BY totalUnitsMoved DESC
LIMIT 10;

-- 11. Which transportation modes are most efficient?
WITH calculatedShipments AS (
    SELECT 
        f.modeDsc AS shippingMode,
        o.orderId,
        o.weight,
        o.TPT AS actualTransitDays,
        o.shipLateDayCount,
        CASE 
            WHEN (o.weight * f.rate) < f.minimumCost THEN f.minimumCost
            ELSE (o.weight * f.rate)
        END AS freightCost
    FROM orderList o
    LEFT JOIN freightRates f 
        ON o.carrier = f.carrier
        AND o.originPort = f.origPortCd
        AND o.destinationPort = f.destPortCd
        AND o.serviceLevel = f.svcCd
        AND o.weight >= f.minWghQty
        AND o.weight <= f.maxWghQty)
SELECT 
    shippingMode,
    COUNT(orderId) AS totalShipments,
    ROUND(SUM(freightCost), 2) AS totalSpend,
    ROUND(SUM(freightCost) / SUM(weight), 4) AS costPerKg,
    ROUND(AVG(actualTransitDays), 1) AS avgTransitDays,
    ROUND((SUM(CASE WHEN shipLateDayCount = 0 THEN 1 ELSE 0 END) / COUNT(orderId)) * 100, 2
    ) AS onTimeRatePercentage,
    ROUND(AVG(shipLateDayCount), 1) AS avgDaysDelayed
FROM calculatedShipments
WHERE shippingMode IS NOT NULL
GROUP BY shippingMode
ORDER BY costPerKg ASC;

-- ADVANCED BUSINESS ANALYTICS QUESTIONS
-- 12. Which products create the highest logistics burden?
SELECT 
    productId,
    COUNT(orderId) AS totalOrdersPlaced,
    SUM(unitQuantity) AS totalUnitsShipped,
    ROUND(SUM(weight), 2) AS totalWeightMovedKg,
    ROUND(SUM(weight) / SUM(unitQuantity), 2) AS avgWeightPerUnit,
    SUM(CASE WHEN shipLateDayCount > 0 THEN 1 ELSE 0 END) AS totalDelayedShipments,
    ROUND((SUM(CASE WHEN shipLateDayCount > 0 THEN 1 ELSE 0 END) / COUNT(orderId)) * 100, 2
    ) AS productDelayRatePercentage,
    ROUND(AVG(shipLateDayCount), 1) AS avgDaysDelayed
FROM orderList
GROUP BY productId
ORDER BY 
	totalWeightMovedKg DESC, 
	totalDelayedShipments DESC;
    
-- 13. Which plants have limited product diversity?
SELECT 
    ppp.plantCode AS plantId,
    COUNT(DISTINCT ppp.productId) AS assignedProductCount,
    COUNT(DISTINCT o.productId) AS activelyShippedProductCount,
    IFNULL(SUM(o.unitQuantity), 0) AS totalUnitsProduced
FROM productsPerPlant ppp
LEFT JOIN orderList o 
    ON ppp.plantCode = o.plantCode
GROUP BY ppp.plantCode
ORDER BY 
	assignedProductCount ASC, 
    totalUnitsProduced DESC;
    
-- 14. Which regions rely too heavily on one carrier?
WITH routeCarrierTotals AS (
    SELECT 
        originPort,
        destinationPort,
        carrier,
        COUNT(orderId) AS carrierRouteOrders,
        SUM(unitQuantity) AS carrierRouteUnits
    FROM orderList
    GROUP BY 
		originPort, 
        destinationPort, 
        carrier),
RouteGrandTotals AS (
    SELECT 
        originPort,
        destinationPort,
        COUNT(orderId) AS totalRouteOrders,
        SUM(unitQuantity) AS totalRouteUnits
    FROM orderList
    GROUP BY 
		originPort, 
        destinationPort)
SELECT 
    rct.originPort,
    rct.destinationPort,
    rct.carrier AS dominantCarrier,
    rct.carrierRouteOrders AS ordersByThisCarrier,
    rgt.totalRouteOrders AS totalCombinedRouteOrders,
    ROUND((rct.carrierRouteOrders / rgt.totalRouteOrders) * 100, 2) AS carrierMarketSharePercentage
FROM RouteCarrierTotals rct
JOIN RouteGrandTotals rgt 
    ON rct.originPort = rgt.originPort 
    AND rct.destinationPort = rgt.destinationPort
WHERE rgt.totalRouteOrders >= 10 
  AND (rct.carrierRouteOrders / rgt.totalRouteOrders) >= 0.70
ORDER BY carrierMarketSharePercentage DESC;

-- 15. What factors most influence shipping delays?
SELECT 
    carrier,
    originPort,
    destinationPort,
    serviceLevel,
    COUNT(orderId) AS totalShipments,
    ROUND(SUM(weight), 2) AS totalWeightMoved,
    SUM(CASE WHEN shipLateDayCount > 0 THEN 1 ELSE 0 END) AS delayedShipmentsCount,
    ROUND((SUM(CASE WHEN shipLateDayCount > 0 THEN 1 ELSE 0 END) / COUNT(orderId)) * 100, 2
    ) AS delayRatePercentage,
    ROUND(AVG(shipLateDayCount), 1) AS avgDaysDelayed,
    MAX(shipLateDayCount) AS maxSingleDelayDays
FROM orderList
GROUP BY 
	carrier,
    originPort, 
    destinationPort,
    serviceLevel
HAVING totalShipments >= 5 
ORDER BY 
	delayRatePercentage DESC,
    avgDaysDelayed DESC;
    
