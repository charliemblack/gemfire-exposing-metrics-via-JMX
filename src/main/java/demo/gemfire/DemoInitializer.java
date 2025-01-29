package demo.gemfire;

import io.micrometer.core.instrument.Clock;
import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.jmx.JmxConfig;
import io.micrometer.jmx.JmxMeterRegistry;
import org.apache.geode.StatisticDescriptor;
import org.apache.geode.Statistics;
import org.apache.geode.StatisticsType;
import org.apache.geode.cache.Cache;
import org.apache.geode.cache.Declarable;
import org.apache.geode.distributed.DistributedSystem;
import org.apache.geode.logging.internal.log4j.api.LogService;
import org.apache.logging.log4j.Logger;

import java.io.IOException;
import java.util.Properties;
import java.util.regex.Pattern;

/**
 * Created by Charlie Black on 6/29/17.
 */
public class DemoInitializer implements Declarable {

    Logger logger = LogService.getLogger();

    MeterRegistry metricRegistry = new JmxMeterRegistry(JmxConfig.DEFAULT, Clock.SYSTEM);

    @Override
    public void initialize(Cache cache, Properties properties) {
        logger.error("DemoInitializer.initialize");
        Properties props = new Properties();
        try {
            props.load(DemoInitializer.class.getResourceAsStream("/expose_metrics.properties"));
        } catch (IOException e) {
            e.printStackTrace();
        }
        DistributedSystem ds = cache.getDistributedSystem();
        final Properties finalProps = props;
        props.stringPropertyNames().forEach(name -> {
            StatisticsType type = ds.findType(name);
            if (type != null) {
                String[] value = finalProps.getProperty(name).split("\\|");
                String statName = ".*";
                String[] statsRegularExpression;
                if (value.length >= 2) {
                    statName = value[0];
                    statsRegularExpression = value[1].split(",");
                } else {
                    statsRegularExpression = value[0].split(",");
                }
                addStatsToRegistry(ds, type, statName, statsRegularExpression);
            }
        });
    }

    private void addStatsToRegistry(DistributedSystem ds, StatisticsType type, String statNameRegex, String[] statsRegularExpression) {
        for (Statistics currStatistics : ds.findStatisticsByType(type)) {
            if (Pattern.matches(statNameRegex, currStatistics.getTextId())) {
                for (StatisticDescriptor currDesciptor : type.getStatistics()) {
                    checkForMatchAndAdd(type, statsRegularExpression, currStatistics, currDesciptor);
                }
            }
        }
    }

    private void checkForMatchAndAdd(StatisticsType type, String[] statsRegularExpression, Statistics currStatistics, StatisticDescriptor currDesciptor) {
        for (String currRegex : statsRegularExpression) {
            currRegex = currRegex.trim();
            if (Pattern.matches(currRegex, currDesciptor.getName())) {
                Gauge.builder(sanitize(type.getName() + "-" + currStatistics.getTextId() + "-" + currDesciptor.getName()), () -> {
                            return currStatistics.get(currDesciptor);
                        })
                        .description(currDesciptor.getDescription())
                        .register(metricRegistry);
            }
        }
    }
    private String sanitize(String value) {
        return value.replaceAll("[:,=\\*\\?\\\\]", "_");
    }

}
